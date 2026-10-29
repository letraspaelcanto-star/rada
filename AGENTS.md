# Rada — fork de Chatwoot CE en modo agencia

Leé esto entero antes de tocar nada. `CLAUDE.md` es un symlink a este archivo: hay un solo juego de reglas para cualquier agente (Claude, Kimi, Codex) y para humanos.

## Qué es este repo

- Fork de [chatwoot/chatwoot](https://github.com/chatwoot/chatwoot) **Community Edition** (MIT) con un CRM de ventas (pipelines kanban, deals, actividades, tareas) para operar clientes de agencia.
- Base upstream actual: rama `develop` @ `cf60e459` (posterior a v4.19.0). Nuestro código empieza en `28c2054a`.
- Lo nuestro vive en el engine `engines/agency_crm/` (modelos, migraciones, specs de modelo) y en rutas con prefijo `crm/` dentro de `app/` (controladores, policies, vistas jbuilder, canal, front Vue). Todo lo propio es grepeable con `crm` o `agency_crm`.
- Documentos que mandan, en este orden: este archivo → `PLAN-DE-PROYECTO.md` §4–5 (contratos congelados v1.0) → `AGENCY.md` (flujo de releases). Si se contradicen, gana el de más arriba y abrís un issue.
- La estrategia de producto (ofertas, verticales, qué es Core y qué satélite) NO vive acá: está en el repo hermano `rada-producto`. No la discutas en issues de código.

## Reglas duras (no negociables)

1. **`enterprise/` no se lee, no se copia, no se adapta, no se "toma de inspiración".** Es código propietario de Chatwoot Inc. El CI falla si un PR lo toca. Si una feature de upstream solo existe en enterprise, se diseña de cero o no se hace.
2. **Aislamiento por cuenta.** Todo modelo nuevo lleva `account_id` NOT NULL con índice; toda query parte de `Current.account` o del scope de la cuenta. Nada se lee ni se escribe sin `account_id`. Cada modelo nuevo trae un spec que prueba que una cuenta no ve datos de otra.
3. **Contratos congelados.** El modelo de datos y la API REST de `PLAN-DE-PROYECTO.md` §4–5 son v1.0. Cambiar un nombre de columna, un enum o una ruta requiere un ADR en `docs/adr/` aprobado por Pablo antes del código.
4. **Toques al core de Chatwoot: mínimos y listados.** Hoy el core tocado es: `Gemfile`, `config/routes.rb` (bloque `namespace :crm`), `db/schema.rb`, `docker/Dockerfile` (COPY engines/), `app/models/{contact,label,team,webhook}.rb` (una línea cada uno), `Sidebar.vue`, `dashboard.routes.js`, `i18n/locale/{en,es}/index.js`. Tocar cualquier otro archivo de upstream es una decisión: se justifica en el PR y se agrega a esta lista.
5. **Eventos hacia afuera por el dispatcher de Chatwoot** (`Rails.configuration.dispatcher.dispatch`), en `after_commit`. Nunca un bus paralelo. Los webhooks nuevos (`deal_created`, `deal_stage_changed`, `deal_won`, `deal_lost`) ya están en `Webhook::SUPPORTED_EVENTS`.
6. **WhatsApp solo por Cloud API oficial.** Nada de Evolution/Baileys/no oficiales en este repo.
7. **Lo que NO va en este repo:** panel de agencia multi-cuenta, billing, white-label, packs por vertical, provisioning. Aunque el PLAN original los menciona (§3, §5 panel de agencia, §6 semanas 7–9), la decisión vigente es que van al kernel/portal, fuera de Chatwoot. Si te piden algo de eso acá, parás y preguntás.
8. **Nada de código de producción se escribe sin spec.** La regla upstream "avoid writing specs unless asked" NO aplica en este fork. Modelo → spec de modelo en `engines/agency_crm/spec`. Controlador → request spec en `spec/controllers/api/v1/accounts/crm`. Canal → `spec/channels/agency_crm`. Store Vue → `spec.js` al lado.
9. **Un ítem por sesión.** Tomás UN ítem del sprint actual (`docs/sprints/actual.md`). Si descubrís otro problema, lo anotás en `docs/sprints/backlog.md` con una línea y seguís. No lo arreglás "ya que estás".
10. **Nadie mergea salvo Pablo.** El agente abre el PR con la plantilla y para. No aprueba, no mergea, no pushea a `develop`/`main`, no borra ramas ajenas, no toca tags.

## Comandos

Usá estos y no otros; si falta uno, agregalo al `Makefile` en el bloque `# --- Fork` y documentalo acá.

```bash
make fork-test     # specs del fork: engine + controladores crm + canal + vitest del store
make fork-lint     # rubocop sobre lo nuestro + eslint de los módulos crm
make fork-ci       # lo mismo que corre GitHub Actions (lint + specs + regresión core)
make run           # overmind con Procfile.dev (upstream)
bundle exec rails agency_crm:seed_ob_pipeline ACCOUNT_ID=<id>   # pipeline OB, idempotente
```

Entorno: Ruby `.ruby-version` (3.4.4) vía rbenv, `pnpm`, Postgres con pgvector, Redis. Dev con Docker: copiá `deploy/docker-compose.override.yaml` a la raíz (app en :3001).

## Terminado significa

- Rama `feat/<slug>` o `fix/<slug>` desde `develop`, PR contra `develop` con la plantilla completa.
- `make fork-ci` verde local y en GitHub. Un spec que se omite con `|| true`, `skip` o `xit` no cuenta como verde.
- Specs nuevos para todo lo nuevo; el spec de aislamiento por cuenta si hay modelo nuevo.
- Strings de UI en `i18n/locale/en/agencyCrm.json` y `es/agencyCrm.json`, nunca hardcodeadas.
- Línea en `CHANGELOG-AGENCY.md` bajo "Sin publicar".
- Sin `TODO`, `binding.pry`, `console.log` ni código muerto en el diff.
- El PR dice qué archivos de upstream tocó (regla 4) y por qué.

## Cómo está armado el CRM (para orientarte rápido)

| Capa | Dónde | Notas |
|---|---|---|
| Modelos | `engines/agency_crm/app/models/agency_crm/` | `Pipeline`, `PipelineStage`, `Deal`, `DealActivity`, `Task`, `BoardMembership`; `AccountExtension` cuelga `has_many` en `Account` |
| Migraciones | `engines/agency_crm/db/migrate/` | Tablas `agency_*`. Generar con `rails g migration` dentro del engine; nunca versión inventada |
| API REST | `app/controllers/api/v1/accounts/crm/` | `pipelines`, `deals`, `deal_activities`, `tasks`. Autorizar con policy → servicio/modelo → jbuilder. Sin lógica en el controlador |
| Policies | `app/policies/agency_crm/` | Pundit, una por recurso; `BoardMembership` decide viewer/editor |
| Vistas JSON | `app/views/api/v1/accounts/crm/` + `app/views/api/v1/models/_crm_*.json.jbuilder` | Un partial por modelo |
| Realtime | `app/channels/agency_crm/pipeline_channel.rb` | Stream `pipeline:<account_id>:<pipeline_id>`; eventos `deal.created/moved/updated` |
| Front | `app/javascript/dashboard/routes/dashboard/crm/`, `stores/agencyCrm.js`, `api/crm*.js`, `composables/useCrmPipelineCable.js` | Vue 3 `<script setup>`, Pinia-style store, Tailwind, `components-next` |
| Seed | `lib/tasks/agency_crm.rake` | Pipeline OB: nuevo → contactado → cotizado → pensando / visito_local → ganado / perdido |

Decisiones ya tomadas que no se rediscuten en un PR: `assignee_id` (no `owner_id`); `priority` con el mismo enum que `Conversation`; `company_id` apunta a `companies` de CE; un deal abierto por pipeline por conversación; deals con soft-delete (`discarded_at`), pipelines/stages hard con restricción.

## Convenciones heredadas de Chatwoot (siguen valiendo)

- Ruby: RuboCop (150 cols), `bundle exec` siempre, `module/class` compactos, excepciones en `lib/custom_exceptions/`.
- Rails: validar presencia/unicidad e indexar; sin SQL crudo (`execute`, heredocs): todo con ActiveRecord; relaciones y scopes en el modelo, el controlador coordina; parámetros validados en el borde con `422`; fallar fuerte ante estado imposible, sin fallbacks especulativos.
- Migraciones: `bundle exec rails g migration <Name>`; nunca versión redondeada a mano.
- Vue/JS: ESLint (Airbnb + Vue 3), Composition API con `<script setup>`, PascalCase para componentes, camelCase para eventos, sin strings sueltos (i18n), `components-next/` para lo nuevo.
- Estilos: solo Tailwind; sin CSS custom, scoped ni inline; colores de `tailwind.config.js`; utilidades lógicas (`ms`, `me`, `start`, `end`).
- i18n: backend en `en.yml`, frontend en `en.json` (y nuestro `es/agencyCrm.json`); nunca editar otros idiomas a mano.
- Specs: `let` y setup por ejemplo, sin helpers custom; `with_modified_env` en vez de stubear `ENV`.
- Commits: Conventional Commits `type(scope): subject`, scope `agency-crm`, `ci`, `fork`, `docs`. Ejemplo: `feat(agency-crm): panel del deal en la conversación`. No se menciona al agente en el commit.
- Sync con upstream: ver `AGENCY.md`. Nunca mergear `upstream/develop` a ciegas: solo tags de release, cada 2 semanas, en PR propio, con `make fork-ci` verde.

## Gente

- **Pablo** — dueño del producto, decide y mergea.
- **Lisandro (Lis)** — infra/DevOps: VM, Caddy, Docker, backups. Cualquier cambio en `docker/`, `deploy/` o workflows de build se le pide revisión.
- **Agentes (Claude, Kimi, Codex)** — construyen un ítem por sesión y revisan PRs. No mergean.
