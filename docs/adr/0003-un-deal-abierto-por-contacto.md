# ADR 0003 — Un deal abierto por contacto y pipeline (no por conversación)

- Fecha: 2026-10-30
- Estado: aceptado (Pablo, 2026-10-30)

## Contexto
El contrato decía "un deal abierto por pipeline por conversación". En OB el mismo cliente escribe por WhatsApp y por Instagram (dos conversaciones), así que esa regla permite dos deals abiertos para la misma venta: el embudo se infla y dos vendedores persiguen al mismo cliente. El estudio del 25/10 (`estudios/2026-10-25-rada-diseno-e-ids.md`, decisión 4) recomienda "por contacto".

## Opciones consideradas
1. Por conversación (como estaba).
2. Por contacto y pipeline.

## Decisión
A lo sumo un deal `open` y no descartado por `(account, contact, pipeline)`.
- Se valida al crear, al reabrir y al cambiar a mano de pipeline o de contacto; la API responde 422 con el id del deal abierto que ya existe.
- Los deals ganados o perdidos no cuentan.
- Excepción: el merge de contactos (ADR 0002) puede dejar dos deals abiertos. No se bloquea: los marca "duplicado por merge: revisar" y crea una tarea.
- Solo validación de modelo, sin índice único en la base, por esa excepción.

## Consecuencias
- "Crear deal" desde la conversación (Sprint 4) abre el deal que ya existe si el contacto tiene uno abierto.
- La migración de leads NocoDB → deals agrupa por contacto.
- Brief: `docs/sprints/briefs/03-un-deal-por-contacto.md`.

## Qué haría cambiar esta decisión
Un cliente que venda varias cosas en paralelo a la misma persona dentro del mismo pipeline (se resolvería con pipelines separados, no volviendo a "por conversación").
