# Changelog del fork (lo nuestro, no upstream)

## Sin publicar
- test(agency-crm): specs de aislamiento por cuenta — la cuenta A no lista ni encuentra registros de la cuenta B en pipelines, deals, deal_activities y tasks (404 en endpoints miembro; index sin registros ajenos), y specs de modelo de `PipelineStage` y `BoardMembership` sobre los scopes de cuenta (Sprint 3.5 ítem 2).
- fix(agency-crm): mover un deal a la etapa ganada/perdida lo cierra (`status`, `closed_on`, `deal_won`/`deal_lost`); salir de ella lo reabre.
- fix(agency-crm): los webhooks `deal_*` llegan a n8n (listener en el engine) y se despachan solo tras commit.
- chore(fork): harness — AGENTS.md del fork, `make fork-*`, plantilla de PR, CI que corre todos los specs del fork.

## Historial
- 2026-10-24 — Sprint 3: kanban Vue + canal ActionCable del pipeline (#4).
- 2026-10-24 — Sprint 2: API REST del CRM + seed pipeline OB (#3).
- 2026-10-23 — Sprint 1: engine `agency_crm` (modelos y migraciones) (#2).
- 2026-10-23 — Primer CI en verde (#1).
- 2026-10-22 — Agency kit: plan, deploy, CI con auditoría de licencia + build GHCR.
