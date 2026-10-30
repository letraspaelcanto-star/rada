# Sprint actual — 3.5 "Hardening" (desde 2026-10-29)

Objetivo: que el CRM sea seguro de poner delante de OB. Nada de features nuevas.
Un ítem por sesión. Al terminar, PR con la plantilla. Criterios verificables.

| # | Ítem | Criterio de aceptación | Estado |
|---|---|---|---|
| 1 | CI corre todos los specs del fork | `ci.yml` ejecuta engine + controladores crm + canal + vitest, sin `\|\| true`; rubocop sobre las rutas reales | Hecho (rada#5, rada#7) |
| 2 | Spec de aislamiento por cuenta en los 6 modelos | Para cada modelo: cuenta A no lista ni encuentra registros de cuenta B vía la API | pendiente |
| 3 | Invariante "un deal abierto por pipeline por conversación" | Validación en `Deal` + spec; `POST /crm/deals` devuelve 422 si ya hay uno | pendiente |
| 4 | Webhooks `deal_*` disparan por el dispatcher | Spec que verifica `dispatch` en `after_commit` para created / stage_changed / won / lost | Hecho (rada#8) |
| 5 | `BoardMembership` aplicada en policies | Viewer no puede `PATCH`; editor sí; spec por policy | pendiente |
| 6 | Paginación y filtros de `GET /crm/deals` | `stage_id`, `status`, `q`, página de 25; spec | pendiente |
| 7 | Decidir base upstream | ADR 0001: ¿quedarse en `develop` @cf60e459 o rebasar a tag v4.19.x? Pablo decide | pendiente (ADR 0001 propuesto) |
| 8 | Ganar/perder desde la etapa | Al mover a etapa `is_won`/`is_lost` el deal cierra (`status` + `closed_on`) | Hecho (rada#9) |
| 9 | Borrados y merge de contactos | — | ADR aprobado por Pablo el 30/10; lo construye Kimi Code |
| 10 | `actor_type` de las actividades lo decide el server, no el cliente | El cliente no puede inyectar `actor_type`; spec | pendiente |
| 11 | La imagen no lleva `enterprise/` | Imagen GHCR sin `enterprise/`; CI que lo verifica | Hecho (rada#6) |

Fuera de este sprint: panel del deal en la conversación, crear deal desde conversación, origen del lead (`referral` / `ctwa_clid`). Van en Sprint 4.
