# frozen_string_literal: true

# ADR 0002: borrar el contacto o el usuario no puede fallar por NOT NULL.
# El contacto sigue siendo obligatorio al CREAR el deal (validación de modelo);
# la columna admite NULL solo para "el contacto fue borrado".
class MakeCrmLinksNullable < ActiveRecord::Migration[7.2]
  def up
    change_column_null :agency_deals, :contact_id, true
    change_column_null :agency_tasks, :assignee_id, true
  end

  def down
    change_column_null :agency_deals, :contact_id, false
    change_column_null :agency_tasks, :assignee_id, false
  end
end
