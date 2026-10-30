# ADR 0001 — Base del fork en tags de release de upstream, no en `develop`

- Fecha: 2026-10-30
- Estado: propuesto (lo aprueba Pablo)

## Contexto

El fork arrancó sobre `develop` de chatwoot/chatwoot (@cf60e459). `develop` es una rama viva: se mueve todos los días, mezcla features sin estabilizar y no ofrece ningún punto de referencia reproducible. Cada commit propio construye sobre una base que cambia, y los syncs cada 2 semanas (regla 4 del plan) hay que resolverlos contra una punta distinta cada vez. Además el fork todavía no tiene tags propios y `docker-build.yml` solo publica imagen con tag `v*`: sin tags no hay imagen. Hoy la línea de release vigente de upstream es v4.19.x (último tag oficial: v4.19.1).

## Opciones consideradas

1. **Quedarse en `develop`**: seguir mergeando `develop` upstream cada 2 semanas. Base siempre actual, pero movediza, sin garantías de estabilidad y con diffs de sync que cambian de forma en cada ciclo.
2. **Basar el fork en tags de release**: rebasar la base al tag oficial más reciente y sincronizar solo contra tags nuevos. Punto estable y reproducible; se llega más tarde a lo que upstream mergea en `develop`.

## Decisión

La base del fork pasa a ser **tags de release de upstream, no `develop`**. El primer tag propio será **`v4.19.0-agency.1`** (nombre provisorio: la base actual es develop posterior a v4.19.0; el número se alinea en el primer sync contra un tag oficial, hoy v4.19.1) al cerrar el Sprint 3.5, y desde entonces el sync se hace contra el **próximo tag oficial** de Chatwoot, no contra la punta de `develop`. El versionado `v<upstream>-agency.<n>` queda así anclado a un release real de upstream.

## Consecuencias

- **Se gana:** base estable y reproducible; merges upstream predecibles (diff tag-a-tag); el número de versión del fork corresponde a un release upstream real; la imagen GHCR empieza a publicarse con el primer tag.
- **Se pierde:** se llega más tarde a los cambios que upstream mergea en `develop` (hay que esperar al próximo tag).
- **Ahora:** cerrar el Sprint 3.5, taggear `v4.19.0-agency.1` y ajustar el flujo de sync para correr contra tags oficiales.

## Qué haría cambiar esta decisión

Un fix crítico (seguridad o bloqueante para clientes) que exista solo en `develop` upstream y sin tag programado a corto plazo: en ese caso conviene llevar ese commit puntual antes del próximo release y reevaluar el ritmo de sync.
