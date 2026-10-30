# Backlog (una línea por hallazgo; no se arregla "ya que estás")

- AGENCY.md dice que el código vive en `agency_crm/` en la raíz; está en `engines/agency_crm/`. Corregir doc.
- El fork no tiene tags; `docker-build.yml` solo corre con tag `v*`. Primer tag cuando Sprint 3.5 cierre.
- Hook pre-commit roto en Windows: `lint-staged` no resuelve por npm y los agentes commitean con `--no-verify`. Arreglar la instalación local o documentar el flujo.
- Regresión core: 4 ejemplos de `spec/models/conversation_spec.rb` ("reply time calculation") fallan localmente en Docker; ajenos al diff de aislamiento (no toca producción). Verificar si son flaky de entorno o falla real en develop; corregir o reportar upstream.
