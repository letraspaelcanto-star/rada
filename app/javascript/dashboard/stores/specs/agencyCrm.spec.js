import { setActivePinia, createPinia } from 'pinia';

import CrmDealsAPI from 'dashboard/api/crmDeals';
import CrmPipelinesAPI from 'dashboard/api/crmPipelines';
import { useCrmStore } from '../agencyCrm';

vi.mock('dashboard/api/crmPipelines', () => ({
  default: { get: vi.fn(), show: vi.fn() },
}));

vi.mock('dashboard/api/crmDeals', () => ({
  default: { update: vi.fn() },
}));

const pipelineResponse = () => ({
  data: {
    payload: {
      id: 7,
      name: 'Ventas OB',
      stages: [
        {
          id: 11,
          name: 'nuevo',
          win_probability: 10,
          deals: [
            { id: 1, title: 'Oportunidad A', stage_id: 11, discarded_at: null },
            {
              id: 2,
              title: 'Descartada',
              stage_id: 11,
              discarded_at: '2026-10-01',
            },
          ],
        },
        { id: 12, name: 'ganado', win_probability: 100, deals: [] },
      ],
    },
  },
});

describe('agencyCrm store', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  it('fetches the pipeline and groups kept deals by stage', async () => {
    CrmPipelinesAPI.show.mockResolvedValue(pipelineResponse());
    const store = useCrmStore();

    await store.fetchPipeline(7);

    expect(store.currentPipeline.id).toBe(7);
    expect(store.stages.map(s => s.id)).toEqual([11, 12]);
    // la deal descartada se filtra
    expect(store.dealsByStage[11].map(d => d.id)).toEqual([1]);
    expect(store.dealsByStage[12]).toEqual([]);
  });

  it('upserts a deal from cable into its stage bucket', async () => {
    CrmPipelinesAPI.show.mockResolvedValue(pipelineResponse());
    const store = useCrmStore();
    await store.fetchPipeline(7);

    store.handleCableEvent({
      event: 'deal.created',
      data: { id: 3, title: 'Nueva', pipeline_id: 7, stage_id: 12 },
    });

    expect(store.dealsByStage[12].map(d => d.id)).toEqual([3]);
    expect(store.dealsByStage[11].map(d => d.id)).toEqual([1]);
  });

  it('moves a deal between stages on deal.updated without duplicating', async () => {
    CrmPipelinesAPI.show.mockResolvedValue(pipelineResponse());
    const store = useCrmStore();
    await store.fetchPipeline(7);

    store.handleCableEvent({
      event: 'deal.updated',
      data: { id: 1, title: 'Oportunidad A', pipeline_id: 7, stage_id: 12 },
    });

    expect(store.dealsByStage[11]).toEqual([]);
    expect(store.dealsByStage[12].map(d => d.id)).toEqual([1]);
  });

  it('ignores cable events from another pipeline', async () => {
    CrmPipelinesAPI.show.mockResolvedValue(pipelineResponse());
    const store = useCrmStore();
    await store.fetchPipeline(7);

    store.handleCableEvent({
      event: 'deal.created',
      data: { id: 9, pipeline_id: 99, stage_id: 12 },
    });

    expect(store.dealsByStage[12]).toEqual([]);
  });

  it('removes a deal on deal.removed', async () => {
    CrmPipelinesAPI.show.mockResolvedValue(pipelineResponse());
    const store = useCrmStore();
    await store.fetchPipeline(7);

    store.handleCableEvent({
      event: 'deal.removed',
      data: { id: 1, pipeline_id: 7 },
    });

    expect(store.dealsByStage[11]).toEqual([]);
  });

  it('moveDeal calls the API with the new stage', async () => {
    CrmDealsAPI.update.mockResolvedValue({});
    const store = useCrmStore();

    await store.moveDeal({ dealId: 1, stageId: 12 });

    expect(CrmDealsAPI.update).toHaveBeenCalledWith(1, {
      agency_pipeline_stage_id: 12,
    });
  });
});
