# Brief — ítem 9: borrados y merge de contactos

**ADR:** `docs/adr/0002-borrados-y-merge.md` (aprobado por Pablo el 30/10). **No lo rediscutas.**
**Rama:** `fix/borrados-y-merge` desde `origin/develop` actualizado (con el ítem 5 mergeado).
**Pieza:** Rada (engine). Sin tocar archivos de upstream: si hace falta alguno, pará y preguntá.

## Problema de hoy

Verificalo primero con un spec que falle:
- `ContactMergeAction` borra el contacto viejo. `Contact has_many :agency_crm_deals, dependent: :nullify` intenta poner `contact_id` en NULL, y la columna es NOT NULL: **el merge de contactos falla entero**.
- Borrar una conversación, una empresa o un usuario que tiene deals o tareas → error de clave foránea.

## Qué

1. **Merge de contactos.** Los deals del contacto que se va pasan al que queda (misma cuenta), **antes** de borrarlo.
   - Va en un módulo del engine (`AgencyCrm::ContactMergeExtension`) que se antepone a `ContactMergeAction` desde `AgencyCrm::Engine#to_prepare`, igual que `WebhookListenerExtension`. No edites `app/actions/contact_merge_action.rb`.
   - Si los dos contactos tienen un deal **abierto** en el mismo pipeline, el merge **no se bloquea**. Los dos deals pasan al contacto que queda, cada uno con una `DealActivity` de sistema "Duplicado por merge de contactos: revisar", y se crea una `Task` para el asignado del deal más nuevo. No se fusionan solos.
2. **Borrar contacto.** `deals.contact_id` → NULL.
   - Migración del engine que quita el NOT NULL; generala con `rails g migration`, nunca con una versión inventada.
   - Validación en `Deal`: el contacto es obligatorio al **crear**, no al actualizar.
3. **Borrar conversación.** `deals.conversation_id` y `tasks.conversation_id` → NULL.
4. **Borrar empresa.** `deals.company_id` → NULL.
5. **Borrar usuario.** `deals.assignee_id` y `tasks.assignee_id` → NULL; la migración hace que `tasks.assignee_id` admita NULL. Las `board_memberships` del usuario se borran.

Los `has_many` de los puntos 3 a 5 van en extensiones del engine (`AgencyCrm::ConversationExtension`, `CompanyExtension`, `UserExtension`), incluidas desde `to_prepare` como `AccountExtension`.

## Specs

Uno por caso, en `engines/agency_crm/spec`:
- merge de dos contactos con deals: termina bien y los deals quedan en el contacto base;
- merge con un deal abierto en el mismo pipeline en cada contacto: termina bien, quedan los dos, con la actividad y la tarea;
- un deal de otra cuenta no se mueve en el merge;
- borrar un contacto, una conversación, una empresa o un usuario: el deal sigue existiendo con ese campo en NULL;
- `POST /crm/deals` sin `contact_id` sigue dando 422.

`spec/actions/contact_merge_action_spec.rb` de upstream tiene que seguir verde. Si en tu entorno local tarda demasiado, que lo confirme el CI de GitHub.
