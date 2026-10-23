# frozen_string_literal: true

class CreateAgencyTasks < ActiveRecord::Migration[7.2]
  def change
    create_table :agency_tasks do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :agency_deal, foreign_key: { to_table: :agency_deals }, index: true
      t.references :conversation, foreign_key: true
      t.references :assignee, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.datetime :due_at
      t.datetime :completed_at
      t.timestamps
    end
  end
end
