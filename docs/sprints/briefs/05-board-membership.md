# Brief — ítem 5: `BoardMembership` aplicada en policies

**Rama:** `fix/board-membership-policies` desde `origin/develop` actualizado.
**Pieza:** Rada (policies + canal del engine). Sin tocar archivos de upstream.

## Qué

| Rol | Puede |
|---|---|
| Administrador de la cuenta | Todo |
| Agente con membresía `viewer` en el pipeline | Leer. `POST`/`PATCH`/`DELETE` → 403 |
| Agente con membresía `editor` | Todo sobre deals, actividades y tareas de ese pipeline |
| Agente sin membresía | El pipeline no aparece en el index; show → 404 |

- `PipelineChannel` (`app/channels/agency_crm`): rechaza la suscripción sin membresía ni rol de admin.
- **Para OB:** `rake agency_crm:seed_ob_pipeline` crea una membresía `editor` para todos los agentes de la cuenta, de forma idempotente. Si no, el día del cambio de imagen nadie ve el kanban.

## Specs

- Uno por policy en `spec/policies/agency_crm/`.
- Uno del canal en `spec/channels/agency_crm/`.
- Uno del seed: crea las membresías, y al correrlo dos veces no las duplica.

## Fuera de alcance

Pantalla para gestionar membresías: hoy se crean por seed o por consola.
