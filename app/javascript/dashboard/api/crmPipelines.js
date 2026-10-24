/* global axios */
import ApiClient from './ApiClient';

// Pipelines del CRM de agencia (PLAN-DE-PROYECTO.md §5).
// Mismo shape snake_case que devuelven los jbuilders.
class CrmPipelinesAPI extends ApiClient {
  constructor() {
    super('crm/pipelines', { accountScoped: true });
  }

  show(id) {
    return axios.get(`${this.url}/${id}`);
  }
}

export default new CrmPipelinesAPI();
