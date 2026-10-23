# frozen_string_literal: true

class CreateAgencyBoardMemberships < ActiveRecord::Migration[7.2]
  def change
    create_table :agency_board_memberships do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :agency_pipeline, null: false, foreign_key: { to_table: :agency_pipelines }, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.integer :role, null: false, default: 0
      t.timestamps

      t.index %i[agency_pipeline_id user_id], unique: true
    end
  end
end
