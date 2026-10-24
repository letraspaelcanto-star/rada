<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';

import { useCrmStore } from 'dashboard/stores/agencyCrm';

const { t } = useI18n();
const route = useRoute();
const crmStore = useCrmStore();

const pipelines = computed(() => crmStore.pipelines);
const isFetching = computed(() => crmStore.uiFlags.fetchingPipelines);
const hasPipelines = computed(() => pipelines.value.length > 0);

onMounted(() => {
  crmStore.fetchPipelines();
});

const kanbanPath = pipelineId =>
  `/app/accounts/${route.params.accountId}/crm/pipelines/${pipelineId}`;

const SEED_COMMAND = 'bundle exec rake agency_crm:seed_ob_pipeline';
</script>

<template>
  <div class="flex flex-col w-full h-full overflow-auto">
    <div class="px-6 pt-6 pb-2">
      <h1 class="text-xl font-medium text-slate-900 dark:text-slate-25">
        {{ t('AGENCY_CRM.TITLE') }}
      </h1>
      <p class="text-sm text-slate-600 dark:text-slate-300">
        {{ t('AGENCY_CRM.SUBTITLE') }}
      </p>
    </div>

    <div v-if="isFetching" class="px-6 py-10 text-sm text-slate-500">
      {{ t('AGENCY_CRM.LOADING_PIPELINES') }}
    </div>

    <div
      v-else-if="!hasPipelines"
      class="px-6 py-10 text-sm text-slate-500 dark:text-slate-400"
    >
      {{ t('AGENCY_CRM.EMPTY_PIPELINES') }}
      <code class="px-1 py-0.5 rounded bg-slate-100 dark:bg-slate-700">
        {{ SEED_COMMAND }}
      </code>
    </div>

    <div
      v-else
      class="grid grid-cols-1 gap-4 px-6 py-4 md:grid-cols-2 lg:grid-cols-3"
    >
      <router-link
        v-for="pipeline in pipelines"
        :key="pipeline.id"
        :to="kanbanPath(pipeline.id)"
        class="p-4 border rounded-xl border-slate-200 dark:border-slate-600 hover:border-slate-400 dark:hover:border-slate-400"
      >
        <h2 class="text-base font-medium text-slate-900 dark:text-slate-25">
          {{ pipeline.name }}
        </h2>
        <p class="mt-1 text-sm text-slate-600 dark:text-slate-300">
          {{ t('AGENCY_CRM.STAGES_COUNT', { count: pipeline.stages_count }) }}
          ·
          {{
            t('AGENCY_CRM.ACTIVE_DEALS_COUNT', {
              count: pipeline.deals_count,
            })
          }}
        </p>
      </router-link>
    </div>
  </div>
</template>
