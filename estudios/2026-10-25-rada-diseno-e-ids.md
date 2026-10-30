# Rada: arquitectura de interfaz e identificadores con el ERP de Ortopedia Belgrano

**Fecha:** 2026-10-25  
**Tipo:** análisis y diseño funcional; no incluye implementación.  
**Alcance:** Rada/Chatwoot CE, engine `agency_crm`, kanban Vue e integración conceptual con `sistema-OB`. No se inspeccionaron ni modificaron VM, NocoDB, n8n, datos o producción.

## Cómo leer este documento

Se distinguen cuatro estados para no confundir intención con realidad:

- **Hoy (UI):** lo que una persona puede hacer en las pantallas inspeccionadas.
- **Hoy (API/modelo):** capacidad técnica existente, aunque no tenga interfaz.
- **Plan:** lo expresado en `PLAN-DE-PROYECTO.md`, todavía no necesariamente implementado.
- **Propuesta:** diseño recomendado en este documento.

Fuentes principales de Rada: `AGENCY.md`; `PLAN-DE-PROYECTO.md` §3–§5.1; modelos y migraciones de `engines/agency_crm/`; rutas, controllers y vistas JSON de CRM; `CrmIndex.vue`, `KanbanBoard.vue` y el panel de conversación. Revisión local: `00cc6b018b`.

Fuentes del ERP: `CLAUDE.md`, `src/adapters/leads.nocodb.js`, `src/core/crmWriteBack.js`, `src/core/crmAtributos.js`, `src/http/crmDocs.js` y archivos complementarios de clientes, documentos, pagos y seguimiento. Las referencias con prefijo `sistema-OB:` corresponden a `github.com/letraspaelcanto-star/sistema-OB`, revisión `f489fe87b5361a977bd7b82bdd9f002614646723`.

## Resumen ejecutivo

1. **Rada tiene hoy un kanban navegable, no un recorrido de venta completo.** Hay selector de pipelines, columnas, tarjetas y drag & drop; no hay alta de oportunidad, ficha, tareas ni integración conversación → oportunidad en la UI.
2. **La conversación debe ser el lugar de trabajo y la oportunidad, el objeto comercial.** El contacto conserva identidad e historial; la tarea expresa la próxima acción; el ERP conserva documentos y cobros. No conviene mantener dos editores para el mismo dato.
3. **El camino feliz propuesto requiere cuatro acciones principales hasta guardar la cotización**, más la carga de datos: crear oportunidad, guardarla, abrir la cotización en el ERP y guardar el presupuesto. El paso a cotizado y el monto real vuelven automáticamente; ganado por pago no exige otra acción en Rada.
4. **Los códigos visibles no son suficientes como claves técnicas.** `C-xxxx`, `P-xxxx`, `R-xxxx` y el número de conversación necesitan contexto. Los vínculos persistentes deben incluir instalación y cuenta de Rada, además del ID interno.
5. **La creación en el ERP se posterga hasta cotizar.** Crear una oportunidad en Rada no crea cliente ni presupuesto. Al cotizar se resuelve primero el vínculo existente y sólo después se busca por teléfono; una ambigüedad se resuelve con una persona, no con un merge automático.
6. **NocoDB deja de ser la fuente de leads mediante un cambio de adaptador, no de pantalla.** `leads.rada.js` debe conservar el contrato y la forma de datos que consume “Mi día”, pero varios campos exigen lecturas compuestas o un nuevo equivalente en actividades/tareas.
7. **La transición necesita un único dueño del estado en cada momento.** La doble escritura bidireccional o el “último que escribe gana” producirían pérdida silenciosa de cambios.

---

# PARTE A — Crítica de estructura y arquitectura de interfaz

## A1. Pantallas y recorridos: hoy versus plan

| Pantalla o recorrido | Estado verificado | Pregunta del usuario | Qué le sobra o qué no debe crecer | Qué le falta para el recorrido comercial |
|---|---|---|---|---|
| **Bandeja de conversaciones** | Existe en Chatwoot CE. El plan la conecta al CRM (`PLAN-DE-PROYECTO.md:56-64`). | “¿Qué conversaciones necesitan atención y cuál tomo ahora?” | Para vender, le sobra depender de etiquetas `fase_*`/`lead_*` como si fueran un segundo pipeline. La bandeja no debe convertirse en otro kanban. | Señal comercial útil junto a la conversación: si tiene oportunidad abierta, etapa y próxima acción; acceso directo a esa oportunidad sin perder filtros ni posición. |
| **Conversación** | Existe. El panel derecho contiene acciones, participantes, información, atributos, conversaciones previas, macros, integraciones, notas y archivos en acordeones (`ContactPanel.vue:147-350`). No se encontró integración CRM en esa pantalla. | “¿Qué pasó con esta persona y qué le respondo?” | Le sobra igualdad visual entre responder, configurar la conversación, editar identidad y hacer seguimiento. No debe repetir una ficha completa de contacto y otra de oportunidad. | Un bloque **Venta** contextual: calificación, oportunidad abierta, próxima acción, presupuesto vigente y una acción principal. Crear/abrir oportunidad sin salir del chat. |
| **Selector de pipelines** | Existe en `/crm`; muestra nombre, cantidad de etapas y oportunidades (`CrmIndex.vue:26-74`). | “¿A qué tablero entro?” | Si la cuenta tiene un solo pipeline de ventas, es una parada intermedia sin decisión. El comando de seed en el estado vacío es lenguaje de operación técnica, no de ventas (`CrmIndex.vue:41-49`). | Entrada directa al pipeline principal; selector sólo cuando hay una elección real. Estado vacío orientado a crear o importar oportunidades. |
| **Kanban** | Existe en `/crm/pipelines/:pipelineId`: ver columnas/tarjetas y mover por drag & drop; ActionCable actualiza el tablero (`KanbanBoard.vue:21-26`, `48-77`). | “¿Cómo está mi cartera y qué oportunidad muevo?” | La probabilidad por columna ocupa jerarquía que el vendedor necesita para próxima acción y aging. La tarjeta sólo muestra título, monto y prioridad (`KanbanBoard.vue:128-154`). | Alta, apertura de tarjeta, ficha, contacto, vendedor, próxima acción, días sin contacto, búsqueda/filtros, totales, estados de sincronización y alternativa móvil al arrastre. Además, el endpoint corta a 100 deals por etapa sin “ver más” ni aviso en la UI (`pipelines/show.json.jbuilder:10-13`). |
| **Ficha de oportunidad** | **No existe en UI.** Sí hay crear/listar/actualizar deals y crear/listar actividades por API (`config/routes.rb:341-344`). El plan prevé ficha lateral y timeline (`PLAN-DE-PROYECTO.md:215-223`). | “¿Qué necesita esta venta para avanzar?” | Como aún no existe, el riesgo es reproducir dentro de ella todo el contacto, todo el chat y todo el ERP. Debe mostrar contexto y enlaces, no duplicar esos módulos. | Etapa, monto y moneda, prioridad, responsable, contacto, conversación, próxima acción, documento ERP, motivo de pérdida y timeline. Debe tener URL propia aunque se presente como drawer. |
| **Tareas / seguimiento** | Modelo y API de crear/actualizar existen; no hay pantalla ni listado REST de tareas en las rutas inspeccionadas (`config/routes.rb:344`). El plan incluye tareas y fechas. | “¿Qué tengo que hacer hoy y a quién estoy dejando enfriar?” | No debe nacer como una libreta separada de las oportunidades ni como una copia independiente de `prox_seg`. | Cola por vencimiento/urgencia, completar y posponer, crear próxima acción desde conversación/ficha y semáforo por etapa. Para OB, la vista ERP “Mi día” debe consumir la misma fuente durante la transición. |
| **Contacto / ficha de persona** | Chatwoot ya ofrece información, atributos, notas y conversaciones asociadas; el deal enlaza `contact_id`. | “¿Quién es esta persona y qué relación tuvimos?” | Le sobra ser tratada como si fuera la oportunidad: una persona puede comprar varias veces. Notas de identidad, estado de una venta y próxima tarea no son el mismo dato. | En Contacto 360: identidad, cliente ERP vinculado, conversaciones y oportunidades históricas. La oportunidad abierta se resume y se abre, no se edita entera en dos lugares. |
| **Cotización** | Ocurre en el ERP, fuera de Rada. Hoy un presupuesto desde lead escribe `doc_erp` e `id_erp` en Chatwoot (`sistema-OB:src/http/crmDocs.js:30-67`). | “¿Qué productos, precio y condiciones le ofrezco?” | No conviene reconstruir el motor de cotización dentro de Rada. | Entrada con la oportunidad ya identificada, retorno al mismo contexto, presupuesto y monto visibles en Rada, y estado de sincronización comprensible. |
| **Panel de agencia** | CE ya tiene super-admin. El panel transversal de salud, provisioning, uso, planes y suspensión es parte del plan, no una pantalla CRM implementada en lo inspeccionado (`PLAN-DE-PROYECTO.md:45-76`, `184-194`). | “¿Qué cuenta cliente necesita atención y cómo va su uso?” | No debe mezclar las tareas de un vendedor con administración de cuentas ni ofrecer un tablero global de contactos/deals fuera de su tenant. | Métricas por cuenta, volumen, SLA/CSAT, agentes, uso facturable, límites y acciones administrativas; acceso restringido a super-admin. |
| **Configuración de pipelines** | Hay API para crear pipelines y reordenar etapas; no se encontró UI de administración en el módulo. | “¿Cómo vende esta empresa y qué significa cada etapa?” | No debería exponer primero probabilidades, automatizaciones y seeds a quien sólo necesita ordenar etapas. | Nombre/orden de etapas, estados terminal, responsables, permisos y mapeo de eventos externos. Las claves técnicas no deben depender del nombre visible. |

### Consecuencia estructural

Hoy el producto ofrece **dos extremos sin el puente**: una conversación rica y un tablero CRM incipiente. El plan acierta al proponer el botón “crear deal”, el panel embebido y la ficha lateral, pero esas tres piezas deben diseñarse como **un solo recorrido con contexto compartido**, no como tres módulos que el usuario tenga que reconciliar.

## A2. Datos y acciones con dos caminos

La regla recomendada es: **una fuente primaria por dato; las demás vistas son resumen, enlace o proyección**. No basta con sincronizar dos formularios si ambos parecen dueños del valor.

| Dato o acción | Caminos actuales o potenciales | Problema | Fuente primaria propuesta | Tratamiento de la otra vista |
|---|---|---|---|---|
| **Etapa de venta** | Etiquetas `fase_*` en conversación; `stage_id` del deal; `estado` en la fila `leads` de NocoDB. | Pueden decir tres cosas distintas. Cambiar una etiqueta no garantiza mover el negocio. | `AgencyCrm::Deal.stage_id` y `status`, con eventos ERP para los hitos financieros. | Etiqueta legacy sólo para migración; NocoDB legacy queda read-only. La conversación muestra etapa, no la edita por etiquetas. |
| **Prioridad / alto valor** | `Conversation.priority`, `Deal.priority`, `lead_type=lead_alto_valor`. | Copiar enums no define cuál se edita ni qué significa cada nivel. | `Deal.priority` para la oportunidad. | La conversación lo presenta como contexto comercial. No usar prioridad de atención como sinónimo silencioso de valor. |
| **Responsable** | `Conversation.assignee_id` y `Deal.assignee_id`. | Quien responde el chat no siempre es quien vende; una copia automática puede asignar mal. | Deal para responsable comercial; conversación para responsable de atención. | Al crear el deal se propone el assignee actual, editable. Después no se sincronizan ciegamente. |
| **Próximo seguimiento** | `prox_seg` en lead y contacto; `agency_tasks.due_at`. | Dos fechas pueden divergir; posponer no siempre significa que exista una tarea clara. | Próxima tarea abierta del deal, con responsable y `due_at`. | `prox_seg` sólo compatibilidad/migración. El contacto muestra el próximo compromiso, sin segundo editor. |
| **Último contacto** | `fecha_ultimo_contacto` en lead, actividad de conversación y actividades del deal. | Mensaje recibido, mensaje enviado y “hablé hoy” no son equivalentes. | Evento explícito de contacto en timeline, con tipo y fecha; la actividad de chat aporta evidencia. | “Mi día” calcula el semáforo desde ese contrato, no desde el máximo de fechas heterogéneas. |
| **Notas** | Notas de contacto, actividades del deal y `nota` del lead. | La nota puede quedar en la persona equivocada o no aparecer al vender de nuevo. | Contacto para hechos persistentes de la persona; deal para esta venta. | Enlazar ambos timelines; no copiar notas automáticamente entre objetos. |
| **Contacto versus oportunidad** | Ficha de contacto y futura ficha de deal. | Si ambas editan etapa, monto y próxima acción, se convierten en dos oportunidades visuales. | Contacto = identidad/historial; deal = negocio puntual. | Contacto 360 lista oportunidades y abre la ficha correspondiente. |
| **Presupuesto** | `doc_erp` en conversación; documento ERP; futuro vínculo en deal. | Un visible `P-xxxx` sin tipo/tenant no es una relación robusta; una conversación puede tener varias ventas. | Documento ERP; deal guarda referencia al presupuesto vigente. | Conversación muestra número y enlace como resumen. `doc_erp` se conserva sólo para compatibilidad. |
| **Trabajo diario** | Futura pantalla Tareas de Rada y pestaña Leads de “Mi día” del ERP. | Dos colas con acciones equivalentes podrían volver a crear doble escritura. | Deals, actividades y tareas de Rada. | Ambas vistas pueden coexistir, pero escriben en la misma API. Para OB, “Mi día” sigue siendo la cabina durante el corte; Rada conversación es el espacio de atención/venta. |
| **Cierre ganado** | Drag & drop a ganado, cambio de `status`, pago verificado ERP, conversión a remito. | Cada evento tiene una semántica distinta; un remito puede tener saldo y un pago puede ser parcial. | Regla comercial explícita basada en pago verificado; ERP emite el hecho y Rada registra el cierre. | El arrastre no debe saltarse la regla. Reembolso/anulación posterior genera excepción, no reescritura automática de historia. |

## A3. Recorrido central del vendedor y conteo de acciones

### Hoy: no hay un total honesto de clics porque el recorrido está interrumpido

**Base de conteo:** conversación ya abierta; se cuentan acciones de navegación/guardado, no tipeo, selección de cada campo ni apertura inicial del chat. Un arrastre se informa como gesto, no como clic.

| Paso | Qué puede hacer hoy | Pantallas y acciones observables |
|---|---|---|
| Entra un chat | Lee y responde en la conversación. | Punto de partida: 1 pantalla, 0 acciones adicionales. |
| Califica | Puede usar mecanismos stock de conversación/contacto; no hay un bloque de calificación del deal. | Cantidad variable según campos; no forma un recorrido CRM único. |
| Crea oportunidad | **No hay control en la UI.** La API sí admite `POST /crm/deals`. | Recorrido de UI interrumpido. No se asigna un número ficticio de clics. |
| Consulta/mueve una oportunidad ya existente | Puede salir a CRM, elegir pipeline y arrastrar una tarjeta. | Desde la conversación: 1 clic en CRM + 1 clic en pipeline = **2 clics y 2 pantallas CRM**; luego 1 gesto de arrastre. La tarjeta no se abre. |
| Cotiza | Lo hace en el ERP. El alta actual desde lead depende de `envio.leadId`, no de un deal (`sistema-OB:src/core/crmWriteBack.js:35-57`). | Al menos un cambio de aplicación; la carga del presupuesto tiene datos variables. No existe un handoff de deal que medir. |
| Gana o pierde | Puede arrastrar una tarjeta a una columna terminal, pero esa acción envía sólo `agency_pipeline_stage_id` (`agencyCrm.js:74-80`): no constituye por sí sola un cierre con `status`, `closed_on` y motivo. No hay ficha ni evento ERP→deal en lo inspeccionado. | 1 gesto para cambiar etapa; cierre completo y enlazado al cobro: **no disponible**. |

**Conclusión:** el recorrido “chat → califica → crea oportunidad → cotiza → gana/pierde” **no se puede completar hoy desde Rada**. Presentar un total numérico ocultaría esa limitación.

### Propuesta: una conversación, un drawer y una salida necesaria al ERP

1. **Calificar en el bloque Venta de la conversación.** Contacto, conversación, pipeline inicial y responsable sugerido ya vienen completos. Producto/origen/prioridad se cargan en el mismo contexto.
2. **Crear oportunidad.** Un clic en “Crear oportunidad” habilita el mínimo formulario; un clic en “Guardar” crea el deal y abre su drawer. No se crea nada todavía en el ERP.
3. **Cotizar.** Un clic en “Cotizar en ERP” abre el presupuesto con una referencia a instalación/cuenta/deal. El ERP resuelve servidor-side el deal y el cliente; el navegador no decide IDs ajenos. Se cargan ítems y se guarda el presupuesto con otra acción.
4. **Volver sin rehacer trabajo.** Al guardar, el ERP mueve el deal a cotizado, guarda el monto real y los vínculos. La conversación/ficha muestra `P-xxxx`, total y estado de sincronización. Volver al chat es un enlace, no un paso obligatorio para completar la integración.
5. **Ganar.** El primer pago verificado que cumpla la regla de cierre mueve el deal a ganado sin acción adicional en Rada.
6. **Perder.** Vencimiento/pérdida informado por el ERP lo cierra automáticamente con motivo. Si el vendedor pierde manualmente, abre “Marcar como perdida”, elige motivo y confirma.

**Camino feliz hasta presupuesto guardado:** **4 acciones principales** —crear, guardar oportunidad, abrir cotización, guardar presupuesto— más carga de datos; **2 espacios de trabajo** —conversación de Rada y cotización del ERP—. El drawer no cuenta como una tercera aplicación ni como navegación separada. **Ganado por pago:** 0 acciones adicionales en Rada. Si el teléfono arroja varios clientes o falta información, aparece una resolución excepcional; no se oculta dentro del camino feliz.

**Qué se elimina:** salir al selector para crear, buscar manualmente el lead en otra cola, copiar el número de presupuesto al chat, actualizar el monto estimado a mano y recordar mover la tarjeta después de cobrar.

## A4. Mockups encontrados y comparación

### Inventario

**No se encontraron mockups de Rada en la copia analizada.** Se revisaron las carpetas del proyecto, `docs/`, nombres de imagen/HTML/PDF, referencias a mockup/wireframe/boceto/prototipo y el historial Git local. `estudios/` no existía al comenzar el relevamiento. Las imágenes encontradas bajo `docs/` corresponden a documentación genérica de Chatwoot, no a propuestas de Rada.

El ERP contiene una referencia textual a una “cabina del vendedor (mockup 20/10/2026)” en `sistema-OB:src/http/routes.leads.js:42-48`, pero no es un artefacto visual de Rada y no se lo contó como tal.

Por lo tanto, **no corresponde inventar una comparación visual contra mockups ausentes**. La comparación posible es contra el prototipo Vue real y el plan:

| Base disponible | Conservar | Corregir o completar |
|---|---|---|
| Kanban Vue actual | Columnas simples, drag & drop, actualización en tiempo real, formato monetario `es-AR`, prioridad con texto y color, navegación account-scoped. | Abrir tarjetas; alta; próxima acción y responsable; filtros; estados vacíos/de error; límite de 100; accesibilidad de teclado; alternativa móvil; no exponer seed técnico al vendedor. |
| Selector de pipelines | Una entrada clara cuando realmente hay varios procesos. | Ir directo al pipeline principal cuando sólo hay uno; mostrar valor y trabajo pendiente, no sólo cantidad de etapas. |
| Plan: botón en inbox + ficha lateral + timeline | Mantener la conversación como origen y la ficha como contexto, con deep link y retorno al mismo lugar. | Evitar un “panel kanban embebido” que reproduzca todo el tablero dentro del chat: el vendedor necesita su oportunidad y próxima acción, no otro tablero comprimido. |
| Plan: atributos en lugar de etiquetas de fase | Una sola etapa por deal; etiquetas sólo transversales; prioridad y vendedor como datos estructurados. | Hacer efectiva la regla de unicidad y definir claves estables de etapa. El plan declara uno abierto por contacto/pipeline, pero el modelo/migración actual no contiene esa validación/constraint (`deal.rb:31-35`, migración `20261023130003:25-27`). |
| “Mi día” del ERP como antecedente funcional | Cola ordenada por urgencia, semáforo por fase, acciones Hecho/Posponer/Cambiar fase/Crear presupuesto y umbral distinto para “pensando”/“visito_local” (`sistema-OB:src/core/seguimientoLeads.js:27-35`, `75-108`). | Cambiar la fuente, no la experiencia: evitar otra lógica de semáforo en Rada que produzca colores distintos para el mismo deal. |

## A5. Arquitectura de pantallas propuesta

| Pantalla | Pregunta que responde | Quién la usa | Qué contiene |
|---|---|---|---|
| **Bandeja** | “¿Qué conversación requiere atención?” | Vendedor, atención, supervisor | Filtros stock; estado de respuesta; indicador discreto de oportunidad abierta, etapa y compromiso próximo; acceso a conversación. |
| **Conversación — workspace principal** | “¿Qué dice el cliente y qué hago ahora?” | Vendedor, atención | Mensajes y respuesta; bloque Venta con calificación, oportunidad abierta, próxima acción y presupuesto; datos de contacto secundarios; una acción principal contextual. |
| **Kanban de ventas** | “¿Dónde está trabada la cartera?” | Vendedor, supervisor | Pipeline principal; buscador/filtros; tarjetas con contacto, monto, responsable, próxima acción y aging; totales; drag & drop más menú “Mover a”; acceso a ficha. |
| **Ficha de oportunidad — drawer con URL propia** | “¿Qué necesita esta venta para avanzar?” | Vendedor, supervisor | Resumen comercial; etapa; monto; responsable; contacto/conversación; próxima tarea; presupuesto vigente y cobro como referencias; timeline; acciones ganar/perder según regla. |
| **Mi seguimiento / Tareas** | “¿Qué tengo que hacer hoy?” | Vendedor, supervisor | Cola por semáforo y vencimiento; Hecho, Posponer, Cambiar etapa; filtros por responsable/equipo; enlaces a chat y ficha. Para OB comparte fuente y reglas con “Mi día”. |
| **Contacto 360** | “¿Quién es y qué relación tuvimos?” | Vendedor, atención | Identidad y medios de contacto; vínculo cliente ERP; conversaciones; oportunidades abiertas e históricas; notas de identidad. No duplica la edición comercial del deal. |
| **Cotización ERP — aplicación enlazada** | “¿Qué le ofrezco y a qué precio?” | Vendedor, administración OB | Cliente resuelto; ítems, precios, totales y condiciones; referencia Rada visible; guardado idempotente; enlace de retorno y diagnóstico de sincronización. |
| **Panel de agencia** | “¿Qué cuenta necesita intervención?” | Super-admin de agencia | Cuentas, salud, volumen, SLA/CSAT, agentes, uso y límites; provisioning/suspensión. No expone datos comerciales cross-account a vendedores. |
| **Configuración de pipelines** | “¿Cómo vende esta cuenta?” | Admin de cuenta, agencia | Etapas y orden; estados terminal; probabilidades para forecast; permisos; mapeo de etapas a eventos ERP; plantillas por rubro. |
| **Excepciones de integración** | “¿Qué no se sincronizó y quién debe resolverlo?” | Admin OB, agencia/soporte | Vínculos ambiguos, altas sin write-back, eventos fallidos o fuera de orden, duplicados y conflictos manuales; reintento con idempotencia y auditoría. No es una pantalla para el vendedor común. |

### Diez principios concretos para la etapa visual

1. **Una pregunta y un botón principal por pantalla o región activa.** En conversación, el CTA cambia entre “Crear oportunidad”, “Ver oportunidad” y “Cotizar en ERP”; nunca compiten los tres como botones primarios.
2. **Una fuente por dato.** Etapa, próxima acción, monto y responsable se editan en su objeto dueño; las demás vistas muestran resumen/enlace. No usar color, etiqueta o sincronización para disimular doble verdad.
3. **El contexto viaja con el recorrido.** La ficha se abre sobre la conversación o el kanban sin perder filtros, scroll ni mensaje; tiene URL propia y “Volver” regresa al origen. El ERP recibe el deal y devuelve al mismo contexto.
4. **Jerarquía de tres niveles.** Primero próxima acción/estado; después monto, cliente y responsable; por último atributos e historial. En tarjeta, la próxima acción y el aging tienen más peso que la probabilidad de etapa.
5. **Densidad progresiva, no acordeones eternos.** El resumen cabe sin expandir; lo secundario se abre bajo demanda. Supervisor puede activar columnas/métricas densas sin imponérselas al vendedor móvil.
6. **El color siempre tiene significado y acompaña texto.** Rojo = vencido/error/urgente; amarillo = requiere atención; verde = al día o ganado según contexto etiquetado; neutro = información. Las etapas no reciben un arcoíris decorativo y ningún estado depende sólo del color.
7. **Toda oportunidad abierta muestra una próxima acción.** Si no tiene, aparece “Sin próxima acción” como estado de trabajo, con CTA para crearla. El semáforo usa las mismas ventanas por etapa en Rada y “Mi día”.
8. **La sincronización es visible y honesta.** Distinguir estimado de total presupuestado, pendiente de sincronizar, sincronizado y fallido. Mostrar `P-xxxx` y monto real sólo cuando el ERP los confirmó; un error no finge éxito ni bloquea la venta.
9. **Celular primero para vender, no kanban horizontal encogido.** “Mi seguimiento” es lista; la ficha es bottom sheet/pantalla completa; mover etapa tiene menú además de arrastre; objetivos táctiles mínimos de 44 px y CTA al alcance del pulgar.
10. **Accesibilidad y estados completos desde el diseño.** Teclado para abrir/mover/cerrar, foco visible, lectura de cambios realtime, contraste suficiente y diseños explícitos de cargando, vacío, error, sin permiso, truncado y conflicto. Ninguna acción crítica depende sólo de drag & drop.

---

# PARTE B — IDs entre Rada/Chatwoot y el ERP

## B1. Inventario de identificadores

### Rada / Chatwoot

| Objeto | Identificadores | Dónde vive | Quién lo crea | Alcance y observaciones |
|---|---|---|---|---|
| **Contacto** | `contacts.id`; atributos opcionales como `custom_attributes.id_erp` | PostgreSQL de Rada | Chatwoot al recibir/crear contacto; usuario o API | `id` es PK de la instalación; toda resolución debe filtrar `account_id`. No es universal entre instalaciones. |
| **Conversación** | `conversations.id` (PK), `display_id` (número visible por cuenta) y `uuid` | PostgreSQL de Rada | Chatwoot al abrir la conversación | `display_id` es único por `account_id`; la API de conversaciones resuelve `:id` como `display_id` (`conversations_controller.rb:190`). En cambio, `Deal.conversation_id` referencia la PK y su controller busca por `id` (`deals_controller.rb:62-64`). **No son intercambiables.** |
| **Oportunidad (deal)** | `agency_deals.id`; `custom_attributes` para referencias externas | PostgreSQL, tabla del engine | Usuario/API de Rada; hoy no desde UI | PK de la instalación; requiere `account_id`. No tiene UUID externo ni columna ERP dedicada en el contrato actual. |
| **Pipeline / etapa** | `agency_pipelines.id`, `agency_pipeline_stages.id`; nombre visible; flags `is_won/is_lost` | PostgreSQL del engine | Seed, admin o API | Los IDs no deben coincidir entre ambientes. El nombre puede cambiar; para integración se necesita mapeo estable por IDs o una clave funcional futura. |
| **Inbox** | `inboxes.id`, `account_id`, `channel_type` | PostgreSQL de Chatwoot | Admin al configurar canal | PK de instalación. Se obtiene desde la conversación; no identifica por sí solo al cliente ni al deal. |
| **Cuenta** | `accounts.id` | PostgreSQL de Chatwoot | Agencia/super-admin | Es el tenant obligatorio de consultas y eventos. En despliegues dedicados, además hay que distinguir la instalación. |

### ERP de Ortopedia Belgrano

| Objeto | Identificadores | Dónde vive | Quién lo crea | Alcance y observaciones |
|---|---|---|---|---|
| **Cliente** | `clientes.Id` de NocoDB → `cliente.id`; código visible derivado `C-xxxx` | Tabla `clientes`; snapshots en documentos | ERP al fichar/crear cliente | `C-xxxx` se deriva del ID numérico y no es una segunda PK (`crmWriteBack.js:29-33`). La deduplicación real por documento DNI/CUIT; teléfono es búsqueda complementaria, no clave única (`clientes.nocodb.js:11-13`, `211-235`). |
| **Presupuesto** | `documentos.Id` → `doc.id`; `tipo='presupuesto'` + `numero`; visible `P-xxxx`; `idempotency_key` | Tabla `documentos` | ERP al guardar presupuesto | La numeración es correlativa por tipo. El prefijo es de presentación: no se guarda como parte de `numero` (`numeroDoc.js:6-16`, `34-39`). |
| **Remito** | `documentos.Id`; `tipo='remito'` + `numero`; visible `R-xxxx`; `presupuesto_id` si nace de conversión | Tabla `documentos` | ERP al convertir/emitir remito | Puede coexistir `P-0085` y `R-0085`; por eso el número pelado no alcanza. `presupuesto_id` apunta al ID interno del presupuesto (`store.nocodb.js:15-36`). |
| **Pago** | `Pagos.Id` → `pago.id`; `payment_code=PAG-xxxx`; `doc_id`, `doc_tipo`, `doc_numero`, `cliente_id`, `idempotency_key` | Tabla `Pagos` | ERP al registrar cobro | El correlativo genera el código; estados incluyen pendiente, verificado, rechazado, anulado y reembolsado. La verificación guarda actor/fecha (`pagos.nocodb.js:15-56`, `100-135`). |
| **Lead legacy** | `leads.Id` → `lead.id` string | Tabla `leads` de NocoDB | n8n al copiar desde Chatwoot; ERP en alta manual | Es una fila legacy, no una entidad comercial definitiva. El ERP lo usa hoy para resolver conversación y contacto al cotizar (`leads.nocodb.js:51-94`). |
| **Referencia a conversación** | `envio.chatwootConversationId`, sólo dígitos; hoy copiado desde `lead.id_chatwoot` | JSON `documentos.envio` | Servidor ERP después de resolver el lead | El navegador no lo elige (`crmWriteBack.js:5-10`). Debe declararse como `display_id` de Chatwoot en el contrato nuevo, no confundirse con `Deal.conversation_id`. |

### Regla de identidad recomendada

Una referencia externa persistente debe responder **sistema + instalación + tenant + objeto + ID**. Para OB, la unidad mínima de un deal es:

**`rada` + `installation_id` + `account_id` + `deal_id`.**

El código visible se guarda aparte para lectura humana. Un entero `42`, `P-0042` o una conversación `#42` sin ese contexto no constituye una identidad global.

## B2. Vínculos que ya existen

| Vínculo | Cómo funciona hoy | Qué resuelve | Límite |
|---|---|---|---|
| **Contacto → cliente** | Al guardar un presupuesto, el ERP escribe `id_erp=C-xxxx` en `Contact.custom_attributes` (`crmWriteBack.js:77-86`). | Encontrar visualmente el cliente ERP desde Chatwoot. | Es un código formateado, sin instalación/tenant ni vínculo inverso sistemático. No prueba unicidad ni sincroniza cambios. |
| **Conversación → presupuesto** | Escribe `doc_erp=P-xxxx` en `Conversation.custom_attributes`. | Ver en el chat qué presupuesto nació de esa conversación. | Es atributo de presentación; no representa bien varias oportunidades/presupuestos ni reemplazos. |
| **Lead → conversación/contacto/inbox** | La fila lleva `id_chatwoot`, `contact_id`, `inbox_id`. | “Mi día”, apertura de chat y write-back del presupuesto. | Depende de n8n y de una tabla intermedia; el ID de conversación es el usado por la API pública, es decir `display_id`. |
| **Documento → lead/conversación** | El browser envía sólo `envio.leadId`; el servidor resuelve la fila y fija `envio.chatwootConversationId` (`crmDocs.js:16-28`). | Evita que el navegador elija una conversación ajena. | El vínculo comercial sigue anclado al lead legacy, no al deal. |
| **Documento → cliente** | `documentos.cliente_id` apunta al ID de la libreta; además se copia un snapshot del cliente. | Ficha e historial de documentos. | Editar el cliente no reescribe documentos emitidos; el vínculo Rada no debe intentar modificar esos snapshots. |
| **Remito → presupuesto** | `documentos.presupuesto_id`. | Trazabilidad de conversión. | No hay relación directa remito→lead por el camino actual; el remito hereda contexto del presupuesto cuando corresponde. |
| **Pago → documento/cliente** | `doc_id` interno más `doc_tipo/doc_numero`; `cliente_id`. | Cobros y verificación sin ambigüedad P/R. | No existe todavía un evento propuesto aquí que cierre el deal; hay que engancharlo a la transición verificada. |
| **Teléfono** | Leads se guardan como `549` + 10 dígitos y el antiduplicado compara los 10 normalizados (`sistema-OB:CLAUDE.md:266`). | Encontrar candidatos cuando falta vínculo. | No es clave única: teléfonos compartidos, cambios de número y clientes distintos producen 0, 1 o varios candidatos. |

## B3. Propuesta de vínculos, creación y duplicados

### Campos canónicos

| Relación | Lado Rada | Lado ERP | Regla |
|---|---|---|---|
| **Contacto ↔ cliente** | Mantener `Contact.custom_attributes.id_erp` para compatibilidad y mostrar `C-xxxx`. Para integración nueva, guardar también el ID crudo en una referencia namespaced si se generaliza a más de un ERP. | Nueva columna JSON `clientes.rada_vinculos`: una entrada por instalación/cuenta con `installation_id`, `account_id`, `contact_id` y fecha de vínculo. | La clave de lectura es la tupla completa. `id_erp` no se usa como única prueba de identidad. Un cliente puede vincularse a contactos de cuentas distintas sin pisar el vínculo anterior. |
| **Oportunidad ↔ presupuesto** | `Deal.custom_attributes.erp` con `source='sistema-OB'`, `cliente_id`, `cliente_numero`, `presupuesto_id`, `presupuesto_numero`, `synced_at` y estado de sincronización. `presupuesto_id` es el ID interno; `P-xxxx` es sólo visible. | En `documentos.envio`, nueva clave `rada` con `installation_id`, `account_id`, `deal_id` y, como contexto no autoritativo, `pipeline_id`. Conservar `leadId` histórico como legacy. | Un presupuesto vigente apunta a un deal; un deal tiene un presupuesto vigente. Versiones/historial quedan en ERP y no crean deals nuevos. |
| **Deal → conversación visible** | El deal conserva su FK interna `conversation_id`; la proyección para ERP/expuestos debe incluir también `conversation_display_id` e `inbox_id`. | `envio.chatwootConversationId` se mantiene como traza legacy/visible. | Nunca copiar el PK del deal a una API pública que espera `display_id`. El conector debe traducir explícitamente. |
| **Migración → origen legacy** | `Deal.custom_attributes.legacy` con `lead_id`, `conversation_display_id`, etiquetas de fase y lote de migración. | Documentos históricos conservan `envio.leadId`; al ser tocados se agrega `envio.rada`, sin borrar el dato anterior. | El ID de fila NocoDB nunca se reutiliza como si fuera `deal.id`; existe un mapa de equivalencias durante el corte. |

**Sobre actualización de atributos:** el adapter actual de Chatwoot ya demuestra que ciertos endpoints reemplazan el hash completo y por eso lee-mezcla-escribe (`sistema-OB:src/adapters/chatwoot.adapter.js:12-16`). El contrato nuevo debe impedir que escribir `erp` borre atributos comerciales ajenos; la actualización tiene que ser por subclave o una fusión servidor-side explícita.

### Orden de creación recomendado

1. **Nace/continúa una conversación en Rada.** No se crea nada en el ERP.
2. **El vendedor califica y crea el deal.** Se valida contacto/cuenta/pipeline. Tampoco se crea cliente ni presupuesto ERP.
3. **El vendedor elige “Cotizar en ERP”.** La referencia contiene instalación/cuenta/deal; el ERP la resuelve con credenciales de servidor y dentro de la cuenta OB configurada. Los IDs del browser son una referencia, nunca una autorización.
4. **El ERP resuelve cliente en este orden:**
   - vínculo `clientes.rada_vinculos` exacto;
   - `id_erp`/ID ya asociado al deal, validado contra el cliente real;
   - documento DNI/CUIT cuando esté disponible;
   - teléfono normalizado a 10 dígitos como búsqueda de candidatos.
5. **Resultado de la búsqueda:** un candidato inequívoco → seleccionar/confirmar; varios → el usuario elige o crea uno nuevo, sin merge automático; ninguno → alta de cliente con los datos disponibles. La venta no se pierde por no encontrar un lead legacy.
6. **Se guarda el presupuesto en ERP.** Primero se asegura el documento con idempotencia. Después se persiste `envio.rada` y se escribe el retorno a Rada; una falla de sincronización queda visible para reintento, pero no invalida el presupuesto, coherente con el comportamiento actual (`crmDocs.js:30-67`).
7. **Rada guarda el presupuesto vigente, el monto real y el vínculo de cliente.** La conversación puede seguir mostrando `doc_erp` como proyección legacy, pero deja de ser la relación principal.

### Duplicados

- **Dos oportunidades para un mismo cliente no son automáticamente duplicados:** una persona puede tener compras sucesivas o necesidades distintas.
- **Regla funcional recomendada:** muchos deals históricos por contacto; **uno abierto por contacto y pipeline**. El plan declara esa regla en §5.1 y también una variante por conversación en §4, pero el modelo actual no la impone. La integración no debe fingir que la base ya la garantiza.
- Al crear/cotizar, si existe un deal abierto candidato, se muestra y se reutiliza para la misma venta. Si se afirma que es una venta distinta, se requiere una decisión explícita según la regla aprobada; nunca se crea otro por simple fallback de teléfono.
- **Un presupuesto no se mueve silenciosamente de deal.** Cambiar `envio.rada` cuando ya apunta a otra oportunidad exige resolución de conflicto y auditoría.
- Reeditar el mismo presupuesto mantiene el deal. Crear una nueva versión comercial puede conservar el mismo deal si reemplaza al presupuesto vigente; el historial queda en ERP. Una nueva oportunidad no hereda automáticamente presupuestos viejos.
- No deduplicar deals globalmente por teléfono. La búsqueda se limita a instalación/cuenta y al tenant OB.

## B4. Eventos que mueven la oportunidad

Los nombres siguientes son **eventos de dominio propuestos**, no una afirmación de que ya exista un bus equivalente en el ERP.

| Hecho de origen | Condición | Cambio en destino | Transporte recomendado | Idempotencia y cautelas |
|---|---|---|---|---|
| **Oportunidad creada en Rada** | Deal válido, aun sin presupuesto | **Nada en ERP**: ni cliente ni presupuesto. El webhook puede quedar para métricas/observabilidad. | Rada emite `deal_created` por dispatcher; si se consume, webhook Rada → n8n. No forma parte del camino crítico. | El reintento no debe crear objetos ERP. No convertir cada chat en deal automáticamente: primero calificación. |
| **Cambio manual de etapa en Rada** | Acción de vendedor/automation | Actualiza el deal; no modifica documentos fiscales ni cobros ERP. | Webhooks `deal_stage_changed`, `deal_won`, `deal_lost` hacia n8n sólo si hay consumidores reales. | Evitar bucles: un cambio originado por ERP lleva origen/evento y no se devuelve como orden contradictoria. |
| **Presupuesto creado o actualizado** | Documento guardado y `envio.rada` resuelto | Deal abierto → etapa `cotizado`; `value_cents` = `valor_total` real convertido a centavos; moneda; IDs P/cliente; fecha de sync. | **ERP → API de Rada**, servidor a servidor, dentro de la cuenta. | Clave basada en documento + revisión/evento. Una actualización vieja no pisa un presupuesto más nuevo ni reabre un deal ganado/perdido. |
| **Pago verificado** | Pago asociado al presupuesto, verificado y que cumple la regla de cierre aprobada | Deal → `status=won`, etapa ganada, `closed_on`; registrar pago/evento en timeline. Conservar como valor del deal el total del presupuesto, no el monto de una seña. | **ERP → API de Rada** al confirmar la transición de pago. | `payment_id` + transición `verificado` como clave. No disparar por comprobante pendiente. No repetir cierre ni actividades en reintentos. |
| **Presupuesto vencido** | El ERP determina vencimiento según su regla comercial y el presupuesto sigue siendo el vigente | Deal → `status=lost`, etapa perdida, motivo `presupuesto_vencido`, fecha. | **ERP → API de Rada** desde el proceso que confirma el vencimiento. | No cerrar si ya fue reemplazado, convertido o pagado. Un evento tardío no pisa ganado. |
| **Presupuesto perdido/rechazado** | Acción/estado ERP que el negocio defina como pérdida | Deal → perdido con motivo normalizado y texto legible. | **ERP → API de Rada**. | Distinguir anulación administrativa de pérdida comercial; no todo documento anulado implica venta perdida. |
| **Reembolso, anulación o salida de verificado** | Ocurre después de ganado | Crear excepción/tarea de revisión; conservar auditoría. | ERP → API de Rada | **No reabrir ni borrar ganado automáticamente.** La decisión comercial y el tratamiento contable pueden diferir. |
| **Remito emitido** | Conversión de presupuesto | Agregar referencia/actividad al deal si resulta útil. No mover etapa por sí solo. | ERP → API de Rada, secundario | Un remito puede coexistir con saldo pendiente; no sustituye la regla de pago. |

### Regla de cierre recomendada para OB

Marcar **ganado con el primer pago verificado de concepto seña o total, de monto positivo y vinculado al presupuesto**. La venta queda ganada y el saldo sigue siendo un problema de Cobros/ERP, no una razón para mantener artificialmente abierta la oportunidad. Un pago `pendiente` nunca cierra; un reembolso posterior abre revisión. Si OB decide que su compromiso comercial exige cobro total, se cambia esta única regla, no el transporte ni el modelo de vínculos.

### Por qué no n8n en el camino financiero crítico

- El ERP ya conoce documento, pago, cliente y estado real; llamar directamente a la API account-scoped reduce traducciones.
- n8n puede continuar para automatizaciones de negocio y observabilidad, pero no debe ser otro escritor de etapa ni un punto necesario para que un cobro se refleje.
- Tanto llamada directa como webhook necesitan credenciales por cuenta, evento identificado, reintentos y reconciliación. La diferencia es que el camino directo conserva una sola cadena de autoridad.

## B5. Reemplazo de `leads` de NocoDB por oportunidades de Rada

### Contrato de adaptador, no cambio de “Mi día”

La pantalla y el núcleo de seguimiento no deben cambiar su modelo de consumo: `/api/leads/seguimiento` sigue devolviendo `{resumen, cola}` y las acciones Hecho/Posponer/Cambiar fase/Crear presupuesto conservan su comportamiento (`routes.leads.js:42-54`, `133-140`). Se reemplaza la fuente mediante **`leads.nocodb.js` → `leads.rada.js`**, manteniendo la interfaz lógica:

- `list()` y `listEstricta()`;
- `get(id)`;
- `update(id, campos)`;
- `create(fila)`;
- la misma forma de lead que espera `fromRecord` y las rutas actuales.

Para OB, `lead.id` puede ser `String(deal.id)` porque el ERP tendrá configurada una única instalación/cuenta Rada. El scope se fija en servidor, como hoy `CHATWOOT_ACCOUNT_ID`; no se acepta una cuenta arbitraria del browser. Si más adelante un mismo ERP atiende varias cuentas, el ID externo debe pasar a una clave opaca compuesta sin cambiar la pantalla, aunque sí el contrato interno de rutas.

**Brechas API a resolver antes del cambio:** hoy hay listado paginado de deals, pero no `GET /crm/deals/:id`; tampoco hay listado de tareas. El pipeline entrega hasta 100 deals por etapa y no es una fuente completa para el conector. Por eso el adaptador necesita lectura account-scoped paginada, detalle y expansiones de contacto/conversación/asignee, no copiar el límite del kanban.

### Equivalencia de columnas

“Directo” significa campo del deal; “compuesto” exige leer objetos asociados; “contrato nuevo” significa que hoy no hay un equivalente confiable con la misma semántica.

| Columna `leads` | Equivalente propuesto en Rada | Tipo / brecha |
|---|---|---|
| `Id` / `lead.id` | `deal.id`, siempre dentro de instalación/cuenta configurada | Directo para OB; no reutilizar el viejo ID NocoDB. |
| `telefono` | `deal.contact.phone_number`, normalizado a 10 dígitos para comparar | Compuesto; no es clave única. |
| `nombre` | `deal.contact.name` | Compuesto. |
| `canal` | `conversation.inbox.channel_type`; para lead telefónico sin conversación, atributo de origen/canal | Compuesto + excepción manual. |
| `fecha_entrada` | `deal.created_at` | Directo. |
| `fecha_ultimo_contacto` | Evento explícito “contacto realizado” en timeline | **Contrato nuevo.** `conversation.last_activity_at` por sí solo no equivale a “hablé hoy”. |
| `id_chatwoot` | `conversation.display_id` | Compuesto y traducción obligatoria: no usar el PK `deal.conversation_id`. |
| `lead_type` | Derivado de `deal.priority` | Requiere mapping; recomendación: `high`/`urgent` → `lead_alto_valor`, `low`/`medium` → normal. |
| `estado` | Etapa del deal; `status` para abierto/ganado/perdido | Directo + mapping por `stage_id` configurado, no por nombre editable. |
| `origen` | `deal.custom_attributes.origen` | Directo como atributo. |
| `vendedor` | `deal.assignee_id` y nombre del usuario de la cuenta | Compuesto. |
| `valor_estimado` | `deal.value_cents / 100`, con `currency` | Directo; tras cotizar representa total real, por lo que el nombre visible puede ser ambiguo. |
| `fase_at` | Fecha del último cambio de etapa en timeline | **Contrato nuevo.** No hay campo materializado; el callback actual emite eventos, no garantiza una actividad histórica. |
| `motivo_perdido` | `deal.lost_reason` | Directo. |
| `categoria` | `deal.custom_attributes.categoria` | Directo como atributo. |
| `sku_consulta` | `deal.custom_attributes.sku_consulta` | Directo como atributo. |
| `contact_id` | `deal.contact_id` | Directo. |
| `prox_seg` | `due_at` de la próxima tarea abierta del deal | Compuesto; requiere consulta de tareas y regla si hay varias. No seguir escribiendo el contacto como segunda fuente. |
| `inbox_id` | `conversation.inbox_id` | Compuesto. |
| `prod` | `deal.custom_attributes.prod` | Directo como atributo. |
| `urgencia` | `deal.custom_attributes.urgencia` | Directo como atributo; no confundir con `priority` de alto valor. |
| `para_quien` | `deal.custom_attributes.para_quien` | Directo como atributo. |
| `que_frena` | `deal.custom_attributes.que_frena` | Directo como atributo. |
| `ultimo_toque` | Resumen del último evento de contacto en timeline | **Contrato nuevo.** No equivale a cualquier nota o mensaje. |
| `ultimo_toque_at` | Fecha del último evento de contacto | **Contrato nuevo.** |
| `tipo_cliente` | Atributo del contacto/empresa; proyección en el lead | Compuesto. Es identidad, no estado de esta venta. |
| `rubro` | Atributo del contacto/empresa | Compuesto. |
| `ficha_at` | Fecha de última calificación completa | **Contrato nuevo:** actividad o atributo fechado explícito. |
| `nota` | Actividad `note` del deal | Equivalente natural. Hoy `nota` es creable en el adapter pero no aparece en `fromRecord`, por lo que no debe suponerse un contrato de lectura existente (`leads.nocodb.js:28-32`, `51-94`). |

### Semáforo y acciones

- `colaSeguimiento` y `resumenSeguimiento` deben seguir recibiendo la misma forma. Las ventanas por fase —nuevo 1/3 días, contactado/cotizado 2/5, visito_local/pensando 7/21— se mantienen como una sola configuración compartida, no se reimplementan con valores distintos (`seguimientoLeads.js:27-35`).
- **Hecho** crea el evento de contacto y reinicia el reloj; no se limita a actualizar una fecha sin historia.
- **Posponer** crea/actualiza la próxima tarea del deal; completar una tarea exige o propone la siguiente para no dejar deals sin acción.
- **Cambiar fase** actualiza `stage_id`/`status` en Rada. Perdido sigue exigiendo motivo.
- **Crear presupuesto** usa el deal como referencia. El servidor lo resuelve y obtiene contacto/conversación; conserva la protección actual contra IDs ajenos.
- **Alta telefónica manual** primero busca/crea el contacto dentro de la cuenta y luego el deal. La lectura estricta sigue siendo necesaria: una caída convertida en lista vacía produciría duplicados. Idealmente la unicidad la impone Rada, no un recorrido completo de todas las filas.

### Corte por fases

1. **Inventario y mapa.** Congelar mapping de etapas, prioridades y cuentas; medir leads con fases múltiples/nulas, conversaciones faltantes y teléfonos ambiguos. Guardar `legacy.lead_id` y el lote en cada deal migrado.
2. **Backfill inicial.** Convertir etiquetas/filas a deals una vez. Resolver por IDs de contacto/conversación antes que teléfono. Generar tabla `legacy_lead_id → installation/account/deal_id` para documentos y enlaces existentes.
3. **Sombra con dirección única.** Mientras n8n/NocoDB sea dueño, Rada migrado es lectura de comparación. Si se copian cambios, sólo en esa dirección. No habilitar todavía edición en ambos.
4. **Reconciliación.** Comparar abiertos por etapa/vendedor, duplicados por contacto/pipeline, vínculos de conversación y presupuestos. Toda diferencia tiene cola de resolución; no “último escritor gana”.
5. **Corte.** Pausar escrituras legacy, aplicar delta final, activar Rada como dueño y cambiar el ERP a `leads.rada.js`. NocoDB queda read-only; las acciones de “Mi día” escriben sólo Rada.
6. **Apagado del copiador.** Después de estabilidad y nueva reconciliación, desactivar el workflow n8n que llena leads. Conservar lectura histórica por un período acordado y luego retirarla.

La doble escritura transitoria, si resulta indispensable, debe ser **espejo unidireccional con dueño declarado**. Nunca dos interfaces editando etapa en dos tablas con reconciliación posterior por fecha.

## B6. Riesgos y mitigaciones de diseño

| Riesgo | Impacto | Mitigación requerida |
|---|---|---|
| **Fuga entre cuentas de la agencia** | Crítico: un deal/cliente/conversación de otra cuenta puede quedar enlazado o expuesto. | Toda query y evento con `installation_id` + `account_id`; credenciales account-scoped; ERP OB configurado sólo con la cuenta OB; validar deal↔contacto/conversación/pipeline; nunca fallback global por teléfono; logs sin datos innecesarios. |
| **Confundir PK de conversación con `display_id`** | Escribir `doc_erp` en otra conversación o no encontrarla. | Contrato con nombres explícitos y traducción en el conector. `Deal.conversation_id` = PK; API pública y `envio.chatwootConversationId` = `display_id`; siempre acompañado de cuenta. |
| **IDs nuevos al migrar `fase_*` a deals** | `envio.leadId`, enlaces y filtros viejos quedan apuntando a una fila que ya no evoluciona. | No reutilizar IDs; mapa legacy→deal; conservar trazas históricas; delta final; actualizar referencias al tocar documentos; no reindexar por posición o nombre de etapa. |
| **Doble escritura durante transición** | Etapas/fechas divergentes y pérdida de cambios sin error visible. | Un dueño por fase, escritura unidireccional, congelamiento en el corte, reconciliación y legacy read-only. |
| **Teléfono como supuesta clave única** | Unir familiares, clientes empresariales o números reasignados. | Sólo fallback dentro del tenant; 1 candidato requiere confirmación según contexto, varios exigen selección; no merge automático. DNI/CUIT conserva prioridad en clientes. |
| **Dos deals abiertos para la misma venta** | Doble forecast, presupuestos cruzados y cierres contradictorios. | Regla uno abierto por contacto/pipeline, reutilización asistida y constraint/validación efectiva antes de integrar. Actualmente el plan la declara pero el modelo no la impone. |
| **Stage/pipeline inconsistentes o referencias cross-account** | Tarjetas en tableros equivocados y potencial exposición. | Además de validar account por separado, validar que la etapa pertenezca al pipeline del deal y que todas las asociaciones pertenezcan a la cuenta. El modelo actual valida account de stage/pipeline, no la pertenencia stage→pipeline (`deal.rb:109-119`). |
| **Etapa terminal sin cierre coherente** | Una tarjeta en Ganado/Perdido puede conservar `status=open`, sin `closed_on` ni motivo, y distorsionar colas y métricas. | Tratar etapa, estado, fecha y motivo como una transición atómica de dominio. El kanban actual envía sólo `stage_id`; no basta con cambiar la columna. |
| **Eventos duplicados, tardíos o fuera de orden** | Reabrir ganados, perder monto nuevo o duplicar timeline. | `event_id`, documento/revisión, `occurred_at`, idempotencia, chequeo de estado vigente y reconciliación. Una escritura fallida queda pendiente; no se convierte en éxito visual. |
| **Regla incorrecta de ganado** | Una seña contada como cobro total o un remito cerrando ventas indebidamente. | Decisión explícita de Pablo; pago verificado asociado al presupuesto; monto del deal = presupuesto; saldo en ERP; reembolso abre excepción. |
| **Reemplazo de hash de atributos** | Escribir `erp` puede borrar origen/producto u otras integraciones. | Fusión servidor-side o escritura por subclave, prueba de preservación y permisos mínimos. |
| **API insuficiente para el conector** | Listas truncadas, N+1, colores distintos o acciones imposibles. | Detalle de deal, paginación completa, expansión de relaciones y consulta de próxima tarea antes del corte. No consumir el kanban de 100/etapa como fuente total. |
| **Nombres de etapa o enums reinterpretados** | “Cotizado” deja de mapear al renombrar; alto valor y urgencia se mezclan. | Mapping por IDs configurados/clave funcional; contrato separado para `priority`, `urgencia` y `lead_type`; versionar equivalencias. |
| **Datos históricos de cliente/documento** | Cambiar snapshots o números visibles rompe impresos y conciliación. | Mantener `C/P/R/PAG`, IDs internos y snapshots; agregar vínculos sin renumerar ni reescribir historia. |
| **Fallo de Rada después de guardar presupuesto/pago** | La venta existe pero el vendedor ve etapa vieja. | Presupuesto/pago no se revierte por sync; marca de pendiente, reintento idempotente y pantalla de excepciones con acción manual. |

---

# Decisiones que debe tomar Pablo

1. **¿Cuál es el objeto comercial principal?**  
   **Recomendación:** el deal. La conversación es canal/historial, el contacto es identidad y la tarea es próxima acción. Retirar `fase_*` como fuente de etapa después de migrar.

2. **¿Cuál es el recorrido de UI que se compromete para el MVP?**  
   **Recomendación:** conversación con bloque Venta + ficha drawer con URL propia + salida a cotización ERP. No construir otro editor completo de contacto ni un kanban miniatura dentro del chat.

3. **¿Cuál es la cabina diaria de OB durante la transición?**  
   **Recomendación:** mantener “Mi día” del ERP como cabina y cambiar sólo su adaptador a Rada. La conversación de Rada es el workspace de atención/venta. Ambas vistas escriben en Rada; no se mantienen dos estados.

4. **¿Se aprueba la regla de una oportunidad abierta por contacto y pipeline?**  
   **Recomendación:** sí, con muchos deals históricos y reutilización asistida del abierto. Antes de depender de ella, hacerla efectiva en modelo/datos; hoy sólo está escrita en el plan.

5. **¿Qué identidad externa se adopta?**  
   **Recomendación:** tupla sistema/instalación/cuenta/objeto/ID. Para presupuestos, `envio.rada` con instalación, cuenta y deal; para clientes, `rada_vinculos`. Conservar `C/P/R/PAG` sólo como códigos visibles y distinguir siempre PK de `display_id` de conversación.

6. **¿Cuál es la cardinalidad oportunidad–presupuesto?**  
   **Recomendación:** un presupuesto vigente por deal y un deal por presupuesto vigente; versiones e historial en ERP. No crear una oportunidad por cada edición ni mover documentos entre deals sin revisión.

7. **¿Cuándo se crea algo en el ERP?**  
   **Recomendación:** recién al cotizar. `deal_created` no crea cliente ni presupuesto. Resolver cliente por vínculo/documento antes que teléfono y pedir decisión humana ante ambigüedad.

8. **¿Qué hecho marca una oportunidad como ganada?**  
   **Recomendación:** primer pago verificado de seña o total, de monto positivo y asociado al presupuesto. No esperar cobro total ni remito; el saldo queda en Cobros. Reembolso/anulación posterior abre revisión, no reabre automáticamente.

9. **¿Qué hechos marcan pérdida y con qué motivos?**  
   **Recomendación:** presupuesto vigente vencido → `presupuesto_vencido`; pérdida/rechazo comercial explícito → motivo normalizado correspondiente. No tratar toda anulación administrativa como pérdida ni permitir que eventos tardíos pisen un ganado.

10. **¿Qué transporte es autoritativo para eventos financieros?**  
    **Recomendación:** ERP → API de Rada directo, con idempotencia y reintentos. n8n queda para observabilidad/automatizaciones no críticas; no hay dos escritores de etapa.

11. **¿Cómo se mapean etapas y calificación al conector?**  
    **Recomendación:** mapping por IDs configurados/claves funcionales, no por nombres; `high`/`urgent` → `lead_alto_valor`, `low`/`medium` → normal; `urgencia` queda como atributo separado. Mantener una única configuración de ventanas del semáforo.

12. **¿Qué se hace con próxima acción y último contacto?**  
    **Recomendación:** próxima tarea abierta del deal para `prox_seg`; evento explícito de contacto en timeline para Hecho/último toque. No seguir usando `prox_seg` del contacto ni `last_activity_at` como sustitutos semánticos.

13. **¿Cómo se aprueba el corte de NocoDB?**  
    **Recomendación:** backfill con mapa legacy→deal, reconciliación, congelamiento breve, delta final y cambio de adaptador. Legacy read-only y luego apagado del copiador n8n. No aceptar doble escritura bidireccional como solución permanente.

14. **¿Qué visibilidad tendrán los errores de integración?**  
    **Recomendación:** una bandeja de excepciones para admin/soporte, con vínculo ambiguo, sync pendiente/fallida, conflicto de presupuesto y evento fuera de orden. El vendedor ve un estado simple y honesto; la venta ERP no se bloquea por write-back.
