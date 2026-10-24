import { frontendURL } from '../../../helper/URLHelper';
import CrmIndex from './pages/CrmIndex.vue';
import KanbanBoard from './pages/KanbanBoard.vue';

const commonMeta = {
  permissions: ['administrator', 'agent'],
};

export const routes = [
  {
    path: frontendURL('accounts/:accountId/crm'),
    name: 'crm_dashboard_index',
    component: CrmIndex,
    meta: commonMeta,
  },
  {
    path: frontendURL('accounts/:accountId/crm/pipelines/:pipelineId'),
    name: 'crm_kanban_board',
    component: KanbanBoard,
    meta: commonMeta,
  },
];
