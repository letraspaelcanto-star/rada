# ADR 0002 — Qué pasa con los deals cuando se borra o se mergea algo

- Fecha: 2026-10-30
- Estado: aceptado (Pablo, 2026-10-30)

## Contexto
Hoy el merge de contactos falla entero si el contacto tiene un deal: `ContactMergeAction` borra el contacto viejo y `dependent: :nullify` choca con `agency_deals.contact_id` NOT NULL. Borrar una conversación, empresa o usuario con deals o tareas da error de clave foránea. En OB el merge es frecuente: el mismo cliente escribe por WhatsApp y por Instagram.

## Opciones consideradas
1. Bloquear los borrados si hay deals: choca con el pedido de borrado de datos personales (Ley 25.326).
2. Borrar los deals en cascada: se pierde el histórico de ventas.
3. Mover en el merge y poner el vínculo en NULL en los borrados: se conserva el histórico y no se bloquea nada.

## Decisión
Opción 3:
- Merge de contactos: los deals pasan al contacto que queda.
- Borrar contacto, conversación, empresa o usuario: ese vínculo del deal (y de la tarea) pasa a NULL; las membresías de board del usuario se borran.
- `agency_deals.contact_id` y `agency_tasks.assignee_id` pasan a admitir NULL. La API sigue exigiendo `contact_id` al crear.
- Todo se implementa en el engine, sin tocar modelos ni acciones de Chatwoot.

## Consecuencias
- Cambia el contrato §4 (`contact_id` NOT NULL → nullable solo para contactos borrados).
- El kanban y los reportes muestran "contacto borrado" cuando `contact_id` es NULL (Sprint 4).
- Brief: `docs/sprints/briefs/09-borrados-y-merge.md`.

## Qué haría cambiar esta decisión
Un requisito legal o contable que obligue a conservar la identidad del contacto en ventas cerradas.
