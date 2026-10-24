<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';

import { useCrmPipelineCable } from 'dashboard/composables/useCrmPipelineCable';
import { useCrmStore } from 'dashboard/stores/agencyCrm';

const { t } = useI18n();
const route = useRoute();
const crmStore = useCrmStore();

const pipelineId = computed(() => Number(route.params.pipelineId));
const pipeline = computed(() => crmStore.currentPipeline);
const stages = computed(() => crmStore.stages);
const dealsByStage = computed(() => crmStore.dealsByStage);
const isFetching = computed(() => crmStore.uiFlags.fetchingPipeline);

const draggingDealId = ref(null);

// Tiempo real: la suscripción al canal del pipeline vive con esta página.
useCrmPipelineCable(() => route.params.pipelineId);

onMounted(() => {
  crmStore.fetchPipeline(pipelineId.value);
});

const PRIORITY_STYLES = {
  low: 'bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-200',
  medium: 'bg-blue-50 text-blue-700 dark:bg-blue-900 dark:text-blue-100',
  high: 'bg-amber-50 text-amber-700 dark:bg-amber-900 dark:text-amber-100',
  urgent: 'bg-red-50 text-red-700 dark:bg-red-900 dark:text-red-100',
};

const formatValue = deal => {
  if (!deal.value_cents) return '';
  try {
    return new Intl.NumberFormat('es-AR', {
      style: 'currency',
      currency: deal.currency || 'ARS',
      maximumFractionDigits: 0,
    }).format(deal.value_cents / 100);
  } catch (e) {
    return `${deal.currency} ${deal.value_cents / 100}`;
  }
};

const onDragStart = (event, deal) => {
  draggingDealId.value = deal.id;
  event.dataTransfer.effectAllowed = 'move';
};

const onDrop = async (event, stage) => {
  event.preventDefault();
  const dealId = draggingDealId.value;
  draggingDealId.value = null;
  if (!dealId) return;

  const deal = crmStore.currentPipeline?.deals
    ? Object.values(crmStore.currentPipeline.deals)
        .flat()
        .find(d => d.id === dealId)
    : null;
  if (!deal || deal.stage_id === stage.id) return;

  // Movimiento optimista: el cable (deal.updated) confirma y reconcilia.
  crmStore.removeDealEverywhere(dealId);
  crmStore.currentPipeline.deals[stage.id].unshift({
    ...deal,
    stage_id: stage.id,
  });
  try {
    await crmStore.moveDeal({ dealId, stageId: stage.id });
  } catch (e) {
    crmStore.fetchPipeline(pipelineId.value);
  }
};
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-hidden">
    <div class="flex items-baseline gap-3 px-6 pt-6 pb-2">
      <router-link
        :to="`/app/accounts/${route.params.accountId}/crm`"
        class="text-sm text-slate-500 hover:text-slate-700 dark:text-slate-300"
      >
        {{ t('AGENCY_CRM.BACK_TO_CRM') }}
      </router-link>
      <h1 class="text-xl font-medium text-slate-900 dark:text-slate-25">
        {{ pipeline?.name || t('AGENCY_CRM.PIPELINE_FALLBACK') }}
      </h1>
    </div>

    <div v-if="isFetching" class="px-6 py-10 text-sm text-slate-500">
      {{ t('AGENCY_CRM.LOADING_BOARD') }}
    </div>

    <div
      v-else
      class="flex flex-1 gap-3 px-6 py-4 overflow-x-auto"
      @dragover.prevent
    >
      <div
        v-for="stage in stages"
        :key="stage.id"
        class="flex flex-col flex-shrink-0 w-72 max-h-full bg-slate-50 dark:bg-slate-800/50 rounded-xl"
        @dragover.prevent
        @drop="onDrop($event, stage)"
      >
        <div class="px-3 pt-3 pb-2">
          <div class="flex items-center justify-between">
            <h2 class="text-sm font-medium text-slate-900 dark:text-slate-25">
              {{ stage.name }}
            </h2>
            <span class="text-xs text-slate-500 dark:text-slate-400">
              {{ dealsByStage[stage.id]?.length || 0 }}
            </span>
          </div>
          <p class="text-xs text-slate-500 dark:text-slate-400">
            {{
              t('AGENCY_CRM.WIN_PROBABILITY', {
                probability: stage.win_probability,
              })
            }}
          </p>
        </div>

        <div class="flex-1 px-2 pb-2 space-y-2 overflow-y-auto">
          <div
            v-for="deal in dealsByStage[stage.id] || []"
            :key="deal.id"
            draggable="true"
            class="p-3 bg-white border rounded-lg cursor-grab border-slate-200 dark:bg-slate-900 dark:border-slate-600 active:cursor-grabbing"
            @dragstart="onDragStart($event, deal)"
          >
            <p class="text-sm font-medium text-slate-900 dark:text-slate-25">
              {{ deal.title }}
            </p>
            <div class="flex items-center justify-between mt-2">
              <span
                v-if="deal.value_cents"
                class="text-xs text-slate-600 dark:text-slate-300"
              >
                {{ formatValue(deal) }}
              </span>
              <span
                v-if="deal.priority && deal.priority !== 'low'"
                class="px-1.5 py-0.5 text-xs rounded-full"
                :class="PRIORITY_STYLES[deal.priority]"
              >
                {{ t(`AGENCY_CRM.PRIORITY.${deal.priority.toUpperCase()}`) }}
              </span>
            </div>
          </div>

          <p
            v-if="!(dealsByStage[stage.id] || []).length"
            class="py-4 text-xs text-center text-slate-400 dark:text-slate-500"
          >
            {{ t('AGENCY_CRM.EMPTY_STAGE') }}
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
