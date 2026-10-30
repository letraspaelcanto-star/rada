# Brief — ítem 10: `actor_type` de las actividades lo decide el server

**Rama:** `fix/actor-type-server` desde `origin/develop` actualizado.
**Pieza:** Rada (controlador `crm/deal_activities`).

## Problema

Hoy `POST /crm/deals/:deal_id/activities` acepta `actor_type` del cliente. Un agente puede firmar una nota como `ai` o `automation`, y eso ensucia el timeline y cualquier reporte de "qué hizo la IA".

## Qué

- El controlador **no** permite `actor_type` ni `actor_id` en los params: los fija el server.
  - Pedido de un usuario autenticado → `actor_type: user`, `actor_id: Current.user.id`.
  - Pedido con token de agent bot o de plataforma → `actor_type: automation`, sin `actor_id`.
- Si el cliente manda `actor_type`, se ignora: no es 422, para no romper a quien ya lo manda.

## Specs

Request specs:
- un agente que manda `actor_type: ai` termina con la actividad como `user` y su id;
- una actividad creada por un agent bot queda como `automation`.
