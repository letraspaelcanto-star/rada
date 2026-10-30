# Sprint actual — 3.5 "Hardening" (desde 2026-10-29)

Objetivo: que el CRM sea seguro de poner delante de OB. Nada de features nuevas.
Un ítem por sesión. Al terminar, PR con la plantilla. Criterios verificables.

## Cómo tomar trabajo (agentes)

1. Leé `AGENTS.md` entero.
2. En la tabla de abajo, tomá **el ítem de menor número en la columna "Orden" cuyo estado sea `próximo`**. Si ninguno está en `próximo`, no hay trabajo: pará y avisá.
3. Leé su brief (columna "Brief") y seguilo al pie de la letra. El brief manda sobre la descripción corta de la tabla.
4. Antes de arrancar, en el mismo PR cambiá el estado de ese ítem a `en curso (rama <tu-rama>)`.
5. Abrí el PR y pará. Al mergearse, W1 lo pasa a `hecho` y deja el siguiente en `próximo`.

Estados: `próximo` (se puede tomar), `en espera` (depende de otro ítem o de una decisión), `en curso`, `hecho`.

| Orden | # | Ítem | Brief | Estado |
|---|---|---|---|---|
| 1 | 5 | `BoardMembership` aplicada en policies (permisos por board) | [briefs/05-board-membership.md](briefs/05-board-membership.md) | próximo |
| 2 | 9 | Borrados y merge de contactos | [briefs/09-borrados-y-merge.md](briefs/09-borrados-y-merge.md) | en espera (después de la 5) |
| 3 | 3 | Un deal abierto por **contacto** y pipeline + validaciones de ids | [briefs/03-un-deal-por-contacto.md](briefs/03-un-deal-por-contacto.md) | en espera (después de la 9) |
| 4 | 10 | `actor_type` de las actividades lo decide el server | [briefs/10-actor-type.md](briefs/10-actor-type.md) | en espera (después de la 3) |
| 5 | 6 | Paginación y filtros de `GET /crm/deals` | [briefs/06-paginacion-deals.md](briefs/06-paginacion-deals.md) | en espera (después de la 10) |
| — | 7 | Decidir base upstream | ADR 0001 (propuesto) | decide Pablo |

**Por qué este orden:** la 9 y la 3 tocan `deal.rb` y no pueden ir en paralelo; la 3 va después de la 9 para que su validación contemple la excepción del merge (ADR 0003).

### Hechos

| # | Ítem | PR |
|---|---|---|
| 1 | CI corre todos los specs del fork | rada#5, rada#7 |
| 2 | Spec de aislamiento por cuenta | rada#11 |
| 4 | Webhooks `deal_*` disparan por el dispatcher, tras commit | rada#8 |
| 8 | Ganar/perder desde la etapa | rada#9 |
| 11 | La imagen no lleva `enterprise/` | rada#6 |

Al cerrar los cinco de arriba: tag `v4.19.0-agency.1` (ADR 0001) y fin del Sprint 3.5.

Fuera de este sprint: panel del deal en la conversación, crear deal desde conversación, origen del lead (`referral` / `ctwa_clid`). Van en Sprint 4.
