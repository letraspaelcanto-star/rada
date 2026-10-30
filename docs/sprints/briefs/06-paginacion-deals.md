# Brief — ítem 6: cerrar paginación y filtros de `GET /crm/deals`

**Rama:** `feat/deals-paginacion` desde `origin/develop` actualizado.
**Pieza:** Rada (controlador `crm/deals` + jbuilder).

## Lo que ya existe (no lo rehagas)

- Paginación con `page` (hoy `RESULTS_PER_PAGE = 30`) y orden por `updated_at desc`.
- Filtros `stage_id`, `status` y `q`, con request specs.

## Lo que falta

1. Página de **25** (lo que dice el criterio del ítem): `RESULTS_PER_PAGE = 25`.
2. Filtro `pipeline_id`.
3. `meta` con `total_pages` además de `count` y `current_page`.
4. Request specs: el filtro `pipeline_id` y la paginación (26 deals → la página 2 trae 1 y `total_pages` es 2).

## Fuera de alcance

El kanban no usa este endpoint: lee los deals desde `GET /crm/pipelines/:id`, con un tope de 100 por etapa. Ese tope es otro tema; anotalo en `docs/sprints/backlog.md` si te parece que hace falta y no lo toques acá.
