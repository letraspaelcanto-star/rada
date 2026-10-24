/* global axios */
import ApiClient from './ApiClient';

// Deals (tarjetas del kanban) del CRM de agencia (PLAN-DE-PROYECTO.md §5).
class CrmDealsAPI extends ApiClient {
  constructor() {
    super('crm/deals', { accountScoped: true });
  }

  create(data) {
    return axios.post(this.url, { deal: data });
  }

  update(id, data) {
    return axios.patch(`${this.url}/${id}`, { deal: data });
  }
}

export default new CrmDealsAPI();
