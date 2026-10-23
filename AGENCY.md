# AGENCIA CRM — Fork de Chatwoot Community Edition

Fork con fines comerciales de la agencia. Ver `PLAN-DE-PROYECTO.md` para el plan completo.

## Identidad del fork

| | |
|---|---|
| Upstream | `github.com/chatwoot/chatwoot` (remote `upstream`) |
| Base inicial | v4.x (completar al crear el fork) |
| Versionado | `v<upstream>-agency.<n>` — ej. `v4.18.0-agency.1` |
| Licencia | MIT (core Chatwoot) + licencia propia para código en `fazer_ai/`-equivalente |
| **Regla inviolable** | El directorio `enterprise/` se preserva intacto y NUNCA se carga en el CE. El CI lo verifica. |

## Qué se agrega sobre el CE (ver contratos congelados v1.0 en PLAN-DE-PROYECTO.md)

1. **Engine `AgencyCrm`** — pipelines kanban, deals, actividades, tareas (`/api/v1/accounts/:account_id/crm/...`)
2. **Panel de agencia** — extiende el super-admin y la platform API existentes (endpoints con prefijo `agency_`)
3. **AI engine provider-agnostic** — OpenAI/Anthropic/Google/local vía endpoint compatible
4. **White-label** — dominio y marca por cuenta

## Flujo de trabajo

```bash
# 1. Traer un release upstream
git fetch upstream
git merge upstream/v4.19.0        # resolver solo conflictos propios
git tag v4.19.0-agency.1
git push origin main --tags       # CI corre tests + auditoría de licencia

# 2. La imagen se publica sola en GHCR (tag v*), y la VM hace pull.
#    Nada de buildear en producción.
```

## Estructura añadida (todo bajo rutas nuevas, nunca en core MIT)

```
agency_crm/            # engine backend (modelos, API, migraciones)
app/javascript/...     # módulos Vue nuevos (kanban)
deploy/                # compose override, .env.example, este README
.github/workflows/     # CI + build/push imagen
```

## Comandos día a día (dev local)

```bash
docker compose up                 # rails en :3001, mailhog web en :8026
docker compose exec rails bundle exec rails c
docker compose exec rails bundle exec rspec engines/agency_crm/spec
docker compose exec rails bundle exec rubocop
docker compose exec vite bin/vite build   # compilar frontend
```
