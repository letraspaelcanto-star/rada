# Backlog (una línea por hallazgo; no se arregla "ya que estás")

- AGENCY.md dice que el código vive en `agency_crm/` en la raíz; está en `engines/agency_crm/`. Corregir doc.
- AGENCY.md menciona panel de agencia, AI engine y white-label como parte del fork; decisión vigente: van al kernel. Corregir doc.
- PLAN-DE-PROYECTO.md §3 / §6 semanas 7–9 idem (panel, billing, white-label). Marcar como "movido al kernel" sin borrar historia.
- `rada-producto/README.md` enlaza `../estudios/2026-10-25-rada-diseno-e-ids.md` que no existe en este repo. Ubicar y commitear el estudio.
- El fork no tiene tags; `docker-build.yml` solo corre con tag `v*`. Primer tag cuando Sprint 3.5 cierre.
- Regresión core: 4 ejemplos de `spec/models/conversation_spec.rb` ("reply time calculation") fallan localmente en Docker; ajenos al diff de aislamiento (no toca producción). Verificar si son flaky de entorno o falla real en develop; corregir o reportar upstream.
