# Plan de Proyecto — Fork de Chatwoot para Agencia Multi-Cliente

**Código provisional:** `chatwoot-fork-agency`
**Fecha:** 2026-10-22
**Objetivo:** Fork MIT de Chatwoot Community Edition, con CRM kanban de ventas + modo agencia SaaS multi-cuenta, en español. MVP vendible en 10 semanas.

---

## 1. Hipótesis central de posicionamiento

> **El único fork abierto (MIT), self-hosted, con kanban CRM de ventas y modo agencia SaaS multi-cuenta, en español nativo para LatAm.**

Nadie ocupa este cruce hoy:

| Competidor | Kanban CRM | Modo agencia | Abierto / sin lock-in | Español LatAm |
|---|---|---|---|---|
| fazer.ai (fork BR) | ✅ nativo | ❌ mono-instancia | ✅ MIT | ❌ pt-BR |
| Conversa Labs (BR) | ✅ | ✅ pero cerrado/SaaS | ❌ | parcial |
| Chatwoot CE stock | ❌ | ❌ (solo multi-cuenta crudo) | ✅ | parcial |
| respond.io / Wati / Gupshup | ❌ (inbox+IA) | parcial | ❌ SaaS cerrado | parcial |
| Pipedrive / HubSpot | ✅ | ❌ | ❌ | ✅ |
| **Nosotros** | ✅ | ✅ | ✅ MIT | ✅ |

Diferenciadores defendibles:
1. **Conversación → deal automático**: cada chat (WhatsApp/IG/email) puede generar/mover un deal sin salir de la app. Pipedrive no vive donde habla el cliente.
2. **Modo agencia real**: visión transversal de cuentas, provisioning por comando, billing por uso, white-label total.
3. **Sin lock-in**: la agencia corre su propio fork; si nosotros desaparecemos, sigue operando.
4. **IA con modelos a elección** (OpenAI/Anthropic/local vía endpoint compatible), no IA atada del vendor.

---

## 2. Reglas de oro del fork (no negociables)

1. **Nada del directorio `enterprise/`** de Chatwoot en producción con clientes. Es licencia propietaria; violarla expone a la agencia y a sus clientes.
2. **Todo código nuevo vive en `engines/` propios o directorio propio** (ej. `agency_crm/`). El core MIT se toca lo mínimo indispensable. Esto define cuánto duele cada merge upstream.
3. **Versionado:** `v<upstream>-agency.<n>` (ej. `v4.18.0-agency.12`). Cada release nuestro declara qué versión upstream trae.
4. **Sync con upstream cada 2 semanas**, con CI que intenta el merge automáticamente y reporta conflictos.
5. **Tests obligatorios por PR** en todo código nuevo (backend RSpec, frontend Vitest).
6. **Contratos primero:** modelo de datos y API del módulo CRM se congelan ANTES de soltar workers (sección 5). Es la decisión más cara de revertir.

Stack: Ruby on Rails + Vue.js + PostgreSQL + Redis (heredado de Chatwoot). Sidekiq para jobs. ActionCable para realtime.

---

## 3. Arquitectura funcional

**Fuera de Rada (decisión 24/10):** el bloque SUPER ADMIN DE AGENCIA (dashboard, provisioning, billing, planes) y el Panel Agencia-in-a-box (white-label, dominio, plantillas por rubro) van al kernel/portal. Inbox y CRM Kanban sí son Rada. Ver AGENTS.md regla 7.

```
┌─────────────────────────────────────────────────────────┐
│  SUPER ADMIN DE AGENCIA (nuevo, fuera de accounts)       │
│  - Dashboard transversal de cuentas cliente              │
│  - Salud: volumen, SLA, CSAT, churn risk                 │
│  - Provisioning: alta/baja de cuenta con un comando      │
│  - Billing: medición de uso por cuenta → factura agencia │
│  - Planes y límites por cuenta                           │
├─────────────────────────────────────────────────────────┤
│  POR CUENTA (cliente final de la agencia)                │
│                                                          │
│  ┌──────────────┐   ┌──────────────────────────────┐    │
│  │ Inbox        │──▶│ CRM Kanban (nuevo engine)    │    │
│  │ omnicanal    │   │ - Boards / Stages / Deals    │    │
│  │ (CE stock)   │   │ - Deal ↔ Conversation link   │    │
│  └──────────────┘   │ - Automations por etapa      │    │
│                     │ - Tasks, fechas, forecast    │    │
│                     └──────────────────────────────┘    │
│  ┌──────────────┐   ┌──────────────────────────────┐    │
│  │ AI Engine    │   │ Panel Agencia-in-a-box       │    │
│  │ (provider-   │   │ (white-label, PWA, dominio   │    │
│  │ agnostic)    │   │  propio, plantillas por rubro)│   │
│  └──────────────┘   └──────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

Decisiones clave:
- **Una instalación, muchas cuentas** (Opción A) como default. Instalación dedicada por cliente (Opción B) como tier premium → misma imagen Docker, distinto valor de config.
- **AI engine como servicio interno** con interfaz provider-agnostic (OpenAI, Anthropic, Google, local/Ollama). No depender de Captain (enterprise).
- **Billing de la agencia**: medir `conversations_count`, `ai_credits_used`, `agents_count`, `accounts_count` por período → exportar facturación. La agencia cobra a SUS clientes por fuera (el MVP no procesa pagos de clientes finales).

---

## 4. Modelo de datos — módulo CRM (Deal/Pipeline)

**✔ CONGELADO v1.0 — 2026-10-22.** Verificado contra el código real de chatwoot/chatwoot (rama `develop`, commits: `conversation.rb` @335191a, `routes.rb` @dc5766f).

Decisiones ancladas en upstream:
- Todo bajo namespace `AgencyCrm`, tenant = `account_id` (patrón heredado de Chatwoot: `Conversation` valida `account_id` presence y todas las queries lo filtran).
- El agente responsable se llama `assignee_id` (convención de `Conversation#assignee`), NO `owner_id`.
- `priority` usa el mismo enum de `Conversation`: `low:0, medium:1, high:2, urgent:3` → sincronización deal↔conversación sin traducción.
- `company_id` linkea a la tabla `companies` que YA existe en CE (con contactos asociados) — no se crea tabla de empresas propia.
- Los usuarios pertenecen a cuentas vía `account_users` (join existente) — el kanban filtra agentes asignables a través de eso.

```ruby
agency_pipelines
  id, account_id, name, description, position, :timestamps

agency_pipeline_stages
  id, account_id, pipeline_id (FK), name, position,
  win_probability (int %), is_won (bool), is_lost (bool),
  automation_config (jsonb)   # reglas al entrar/salir de etapa
  :timestamps

agency_deals
  id, account_id, pipeline_id (FK), stage_id (FK),
  title, value_cents (bigint), currency (string, default "ARS"),
  contact_id (FK → Chatwoot contacts), conversation_id (FK → conversations, nullable),
  company_id (FK → Chatwoot companies, nullable),   # ya existe en CE
  assignee_id (FK → users, nullable),               # convención Conversation#assignee
  priority (integer, enum: low:0, medium:1, high:2, urgent:3),  # MISMO enum que Conversation
  expected_close_on (date), closed_on (date),
  status (enum: open, won, lost), lost_reason (text),
  custom_attributes (jsonb),
  discarded_at (datetime, nullable),                # soft-delete
  :timestamps
  index: [account_id, stage_id], [account_id, status], [contact_id]

agency_deal_activities          # timeline del deal
  id, account_id, deal_id (FK), actor_type (user|system|ai|automation),
  actor_id (nullable), kind (enum: note, stage_change, message_link,
  task_created, call, email, system), body (text), metadata (jsonb),
  :timestamps

agency_tasks
  id, account_id, deal_id (FK, nullable), conversation_id (FK, nullable),
  assignee_id (FK → users), title, due_at, completed_at, :timestamps

agency_board_memberships        # control de acceso por board
  id, account_id, pipeline_id (FK), user_id (FK), role (enum: viewer, editor),
  :timestamps
  unique: [pipeline_id, user_id]
```

Invariantes:
- Todo query filtra por `account_id` (test automatizado que lo verifique en cada modelo nuevo — crítico para no filtrar datos entre clientes de la agencia).
- `conversation_id` es 0..1. **Un contacto** puede tener a lo sumo un deal abierto por pipeline (constraint lógica, no DB; ADR 0003 — antes decía "una conversación").
- Las etapas `is_won/is_lost` son únicas por pipeline.
- `priority` del deal replica el enum de `Conversation` — la sincronización deal↔conversación es copia directa de valor, sin mapeo.
- Borrado: deals en soft-delete (`discarded_at`), pipelines/stages hard con restricción si tienen deals.
- Los agentes asignables salen de `account_users` (join existente users↔accounts), nunca de `users` global.

---

## 5. Contratos de API (resumen)

**✔ CONGELADO v1.0 — 2026-10-22** (misma verificación upstream que sección 4).

## 5.1 Decisión congelada — pipeline seed OB y regla atributos vs. etiquetas

**Decisión (2026-10-22):** no reconstruir el sistema de etiquetas `lead_*`/`fase_*` de OB dentro del Chatwoot stock (propuesta del 21/10). Se resuelve sobre la estructura definitiva de Rada:

1. **La fase de venta es un pipeline de deals, no una etiqueta.** Un deal tiene exactamente UNA etapa activa — la regla "una etiqueta = una pregunta, una activa" deja de depender de disciplina manual y la impone el modelo de datos (constraint en `agency_deals.stage_id`).
2. **Pipeline seed — recorrido real de OB** (valida el kanban con datos verdaderos desde el día 1):

```
nuevo → contactado → cotizado → pensando / visito_local → ganado / perdido
```

   Se carga como seed idempotente del engine (migración o rake task `agency_crm:seed_ob_pipeline`), asociado a la account de OB. `ganado` y `perdido` son stages con `is_won`/`is_lost` (probabilidades: ganado 100, perdido 0; intermedias a calibrar con datos reales).
3. **Atributos, no etiquetas** (parte de la propuesta del 21/10 que SÍ se aprueba, es independiente del fork): producto, origen y vendedor pasan a atributos — en Rada, `custom_attributes` del deal/contact y `assignee_id` del deal (vendedor). Las etiquetas de Chatwoot quedan solo para agrupación transversal (no para estado ni cualificación).
4. **Cualificación** (`lead_alto_valor`) queda como `priority` del deal (enum alineado a Conversation) — no como etiqueta.
5. **Migración posterior:** cuando el fork esté, OB migra etiquetas → deals UNA vez, sobre esta estructura. Diseñar la migración sobre el contexto real (el conteo de hoy: leads con fases múltiples/nulas).

Invariante añadido: un contacto puede tener muchos deals a lo largo del tiempo, pero a lo sumo uno abierto por pipeline (ya cubierto en §4).

**✔ CONGELADO v1.0 — 2026-10-22** (misma verificación upstream que sección 4).

REST bajo `/api/v1/accounts/:account_id/` — confirmado contra `config/routes.rb`: las rutas account-scoped de CE viven exactamente ahí (`namespace :api → :v1 → resources :accounts → scope module: :accounts`). Auth: API token existente. Todo endpoint nuevo del módulo CRM lleva prefijo `crm/` para ser grepeable en los diffs con upstream.

```
GET    /crm/pipelines                      → lista de boards
POST   /crm/pipelines
GET    /crm/pipelines/:id                  → board con stages + deals por stage
PATCH  /crm/pipelines/:id/stages/reorder   → { stage_ids: [...] }
POST   /crm/deals                          → crea deal (puede link conversation_id)
GET    /crm/deals?stage_id=&status=&q=     → filtros + paginación
PATCH  /crm/deals/:id                      → incl. stage_id (dispara automations)
POST   /crm/deals/:id/activities           → nota / evento
GET    /crm/deals/:id/activities           → timeline
POST   /crm/tasks  ·  PATCH /crm/tasks/:id
```

Realtime: canal ActionCable dedicado `pipeline:<account_id>:<pipeline_id>` — eventos `deal.created`, `deal.moved`, `deal.updated` (el kanban se actualiza sin refresh). Para webhooks hacia afuera, en cambio, se emite a través del **dispatcher existente** de Chatwoot (`Rails.configuration.dispatcher.dispatch`), igual que hace `Conversation` — no se crea un bus paralelo.

Webhooks hacia afuera (para n8n): `deal_created`, `deal_stage_changed`, `deal_won`, `deal_lost` — payload incluye `custom_attributes` y datos de la conversación linkeada.

**Fuera de Rada (decisión 24/10):** va al kernel/portal. Ver AGENTS.md regla 7.

Panel de agencia — **NO se crea namespace `/agency/` nuevo**: se extiende lo que ya existe en CE:
- **Super-admin web** (ya existe en CE): namespace `/super_admin` con devise `SuperAdmin`, CRUD de accounts, `seed`, `reset_cache`. Nuestro panel de agencia vive acá, montado como controladores/vistas del engine dentro de ese namespace.
- **Platform API** (ya existe en CE): `/platform/api/v1/accounts` con CRUD completo de cuentas y `account_users`. El provisioning programático se extiende acá:

```
GET  /platform/api/v1/agency/overview              → todas las cuentas + métricas del mes (nuevo)
POST /platform/api/v1/accounts/:id/agency_suspend  → suspender (nuevo)
GET  /platform/api/v1/accounts/:id/agency_usage?period=YYYY-MM  → métricas de facturación (nuevo)
```

Todo endpoint nuevo del panel lleva prefijo `agency_` sobre recursos existentes, para distinguirlo de upstream en los merges.

---

## 6. Plan de 10 semanas

### Semana 0 (ya, en paralelo al fork)
- [ ] Instalar Chatwoot CE stock en producción (Opción A), 1–2 clientes piloto pagos.
- [ ] n8n + webhooks para automatizaciones básicas (etiquetado, asignación).
- [ ] Arrancar trámite de Meta Business + WhatsApp Business API (app review tarda semanas; empezar YA).
- **Salida:** ingresos + feedback de producto mientras se construye el fork.

### Semanas 1–2 — Cimientos
| WS | Entregable |
|---|---|
| Core | Fork limpio, CI, convención de versionado, entornos review por PR |
| CRM Backend | Migraciones del modelo (sección 4), modelos + specs |
| Frontend | Scaffold de rutas Vue, layout del módulo CRM, design tokens |
| Infra | Docker compose dev reproducible, seeds con datos de demo |
| QA | Suite de tests corriendo en CI, linter, chequeo de `account_id` en queries |

### Semanas 3–5 — Corazón del producto
| WS | Entregable |
|---|---|
| CRM Backend | CRUD completo de pipelines/stages/deals + reorder + filtros |
| CRM Backend | Automation engine por etapa (al entrar/salir: webhooks, tareas, mensajes programados) |
| Frontend | Kanban con drag & drop (vuedraggable), tarjeta de deal, ficha lateral con timeline |
| Frontend | Integración con inbox: botón "crear deal" en conversación, panel kanban embebido |
| AI | AI engine provider-agnostic: resumen de conversación, sugerencia de etapa, transcripción de audio |
| Agencia | Super-admin: dashboard transversal + provisioning de cuentas |

### Semanas 6–7 — Modo agencia + white-label

**Fuera de Rada (decisión 24/10):** va al kernel/portal. Ver AGENTS.md regla 7.

- [ ] Panel agencia completo: métricas por cuenta, límites por plan, suspensión.
- [ ] Billing de uso por cuenta (medición + export).
- [ ] White-label: dominio por cuenta, PWA con marca, emails transaccionales.
- [ ] Plantillas por rubro (packs: odontología, inmobiliaria, retail): pipeline + automations + prompts prearmados.
- [ ] Helm chart / plantilla de instalación dedicada (Opción B lista como tier premium).

### Semanas 8–9 — Hardening
- [ ] Tests de regresión sobre canales (WhatsApp, Instagram, email) con el fork.
- [ ] Auditoría de licencia: script que verifica que `enterprise/` no se carga en runtime del CE.
- [ ] Performance: N+1 en kanban, índices, paginación de boards grandes.
- [ ] Primer sync upstream documentado (merge `v4.18.x` o el vigente).
- [ ] Docs: README del fork, CHANGELOG, guía de instalación para agencias.

### Semana 10 — Piloto del fork
- [ ] 1 cliente real migrado al fork (de la base piloto de la semana 0).
- [ ] Fixes críticos del piloto.
- [ ] **Lanzamiento MVP vendible.**

### Post-lanzamiento (semana 12+)
- Edición Pro propia (kanban avanzado, forecast, reportes) — código en directorio propio con licencia propia por instancia (modelo fazer.ai: ~R$ 129,90/mes por dominio como referencia).
- Instalaciones dedicadas por comando (Opción B).
- Comunidad/español: curso + plantillas + soporte (modelo Lucas Moreira / Conversa Labs).

---

## 7. Asignación de workers agenticos

| Worker | Rol | Stack |
|---|---|---|
| W1-Core | Mantenedor del fork, merges upstream, CI | git, Rails |
| W2-Backend | Engine CRM, API, automations | Rails, RSpec |
| W3-Frontend | Kanban Vue, integración inbox | Vue 3, Pinia, Vitest |
| W4-AI | AI engine, transcripción, sugerencias | Python/TS según diseño, LLM APIs |
| W5-Agency | Super-admin, billing, white-label, provisioning | Rails + Vue |
| W6-Infra/QA | Docker, Helm, seeds, tests E2E, auditoría licencia | Docker, CI, Playwright |

Reglas de coordinación:
- W2 y W3 trabajan contra los contratos de la sección 5 (congelados en semana 1; cambios solo con aprobación).
- Todo PR pasa CI + review de W1 antes de merge.
- W1 intenta merge upstream cada 2 semanas; si los conflictos superan un umbral, escala a decisión humana.

---

## 8. Riesgos y mitigaciones

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Meta app review de WhatsApp se atrasa | Alto (ventas) | Piloto con Baileys/Cloud API ya aprobadas; no bloquear el fork por esto |
| Drift con upstream | Medio-alto | Cambios aislados en engines, sync cada 2 semanas, CI de merge |
| Fuga de datos entre cuentas | Crítico (legal) | Tests automáticos de `account_id`, auditoría de queries, pentest antes de piloto |
| Violar licencia enterprise sin querer | Crítico (legal) | Script de auditoría en CI que falla si `enterprise/` se carga |
| Agents generan deuda técnica | Medio | Contratos congelados, tests obligatorios, review de W1 |
| Competidor (fazer.ai) internacionaliza a español | Medio | Velocidad + foco modo agencia que ellos no tienen |

---

## 9. Modelo de negocio (referencia)

- **Open core:** fork CE MIT gratuito (adquisición/comunidad) + edición Pro propia por instancia (kanban avanzado, forecast, reportes, chat interno extendido).
- **Referencia de pricing Pro:** R$ 129,90/mes por dominio, usuarios ilimitados (referencia fazer.ai). Para LatAm hispana: ~US$ 25–35/mes por dominio.
- **Objetivo agencia tipo:** 30 cuentas cliente × margen propio. La agencia cobra a sus clientes US$ 50–150/mes por atención con IA; su costo de plataforma es el Pro por dominio dedicado o la instalación multi-cuenta.

---

## 10. Próximos pasos inmediatos

1. Aprobar/congelar modelo de datos y contratos (secciones 4–5).
2. Crear repo fork + CI + convención de versionado (W1).
3. Levantar CE stock + n8n + clientes piloto (Semana 0).
4. Iniciar trámite Meta WhatsApp Business.
5. Sprint 1 con W2/W3 contra los contratos.
