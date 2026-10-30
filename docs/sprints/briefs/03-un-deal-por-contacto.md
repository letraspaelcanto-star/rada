# Brief — ítem 3: un deal abierto por contacto y pipeline + validaciones de ids

**ADR:** `docs/adr/0003-un-deal-abierto-por-contacto.md` (aprobado por Pablo el 30/10). Cambia el contrato: antes decía "por conversación".
**Rama:** `fix/validaciones-deal` desde `origin/develop` actualizado (con el ítem 9 mergeado).
**Pieza:** Rada (engine + controladores `crm/`).

## Qué

1. **En `AgencyCrm::Deal`:** a lo sumo un deal con `status` open y `discarded_at` nil por `(account, contact, pipeline)`.
   - Se valida al crear, al reabrir (status pasa a open, o el deal sale de una etapa terminal) y al cambiar a mano de pipeline o de contacto.
   - `POST`/`PATCH /crm/deals` → 422, y el error incluye el id del deal abierto que ya existe.
   - Los deals ganados o perdidos no cuentan.
   - **Solo validación de modelo, sin índice único en la base:** el merge de contactos (ítem 9) puede dejar dos deals abiertos a propósito y no tiene que fallar.
2. **Etapa del mismo pipeline.** La etapa tiene que pertenecer al **mismo** pipeline del deal. Hoy solo se valida la cuenta, así que un `PATCH` con una etapa de otro board deja la tarjeta huérfana.
3. **Ids de otra cuenta.** `conversation_id`, `company_id` y `assignee_id` de otra cuenta → 422 (hoy se ignoran en silencio).
   - En tasks, un `agency_deal_id` o un assignee de otra cuenta → 422.
   - **Sacá el `pending` de `'rejects a deal from another account on create'`** en `spec/controllers/api/v1/accounts/crm/tasks_spec.rb`: ese spec es el contrato.

## Specs

- De modelo, en `engines/agency_crm/spec`.
- Request specs, con cada caso de 422.
- El spec del merge del ítem 9 tiene que seguir verde.

**No toques** el `before_save` de status/`closed_on` ni el dispatch en `after_commit` de `deal.rb`.
