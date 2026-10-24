import { defineStore } from 'pinia';

import CrmDealsAPI from 'dashboard/api/crmDeals';
import CrmPipelinesAPI from 'dashboard/api/crmPipelines';

// Store del kanban CRM de agencia (PLAN-DE-PROYECTO.md §5).
//
// El shape de los deals es snake_case tal cual vienen del backend (jbuilder
// y cable usan el mismo shape, ver cable_payload en AgencyCrm::Deal), así
// REST y tiempo real se tratan igual — no hay camelcase intermedio.
export const useCrmStore = defineStore('agencyCrm', {
  state: () => ({
    pipelines: [],
    uiFlags: {
      fetchingPipelines: false,
      fetchingPipeline: false,
      movingDeal: false,
    },
    // pipeline completo: { id, name, stages: [...], deals: { [stageId]: [...] } }
    currentPipeline: null,
  }),

  getters: {
    stages: state => state.currentPipeline?.stages || [],
    dealsByStage: state => {
      const grouped = {};
      (state.currentPipeline?.stages || []).forEach(stage => {
        grouped[stage.id] = [];
      });
      Object.entries(state.currentPipeline?.deals || {}).forEach(
        ([stageId, deals]) => {
          grouped[stageId] = deals;
        }
      );
      return grouped;
    },
  },

  actions: {
    async fetchPipelines() {
      this.uiFlags.fetchingPipelines = true;
      try {
        const { data } = await CrmPipelinesAPI.get();
        this.pipelines = data.payload || [];
        return this.pipelines;
      } finally {
        this.uiFlags.fetchingPipelines = false;
      }
    },

    async fetchPipeline(id) {
      this.uiFlags.fetchingPipeline = true;
      try {
        const { data } = await CrmPipelinesAPI.show(id);
        const stages = data.payload.stages || [];
        const deals = {};
        stages.forEach(stage => {
          deals[stage.id] = (stage.deals || []).filter(
            deal => !deal.discarded_at
          );
        });
        this.currentPipeline = {
          id: data.payload.id,
          name: data.payload.name,
          stages,
          deals,
        };
        return this.currentPipeline;
      } finally {
        this.uiFlags.fetchingPipeline = false;
      }
    },

    async moveDeal({ dealId, stageId }) {
      this.uiFlags.movingDeal = true;
      try {
        // El cable devuelve el deal.updated y el store se actualiza solo;
        // el await acá solo confirma que el servidor aceptó el cambio.
        await CrmDealsAPI.update(dealId, { agency_pipeline_stage_id: stageId });
      } finally {
        this.uiFlags.movingDeal = false;
      }
    },

    // --- Tiempo real (ActionCable pipeline:<account>:<pipeline>) ---

    upsertDealFromCable(deal) {
      if (!this.currentPipeline || deal.pipeline_id !== this.currentPipeline.id)
        return;
      this.removeDealEverywhere(deal.id);
      if (deal.discarded_at) return;
      const bucket = this.currentPipeline.deals[deal.stage_id];
      if (bucket) bucket.unshift(deal);
    },

    removeDealEverywhere(dealId) {
      if (!this.currentPipeline) return;
      Object.values(this.currentPipeline.deals).forEach(bucket => {
        const index = bucket.findIndex(d => d.id === dealId);
        if (index !== -1) bucket.splice(index, 1);
      });
    },

    handleCableEvent({ event, data }) {
      if (!data) return;
      if (event === 'deal.created' || event === 'deal.updated') {
        this.upsertDealFromCable(data);
      } else if (event === 'deal.removed') {
        this.removeDealEverywhere(data.id);
      }
    },
  },
});
