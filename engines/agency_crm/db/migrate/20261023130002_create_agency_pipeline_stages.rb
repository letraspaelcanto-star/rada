# frozen_string_literal: true

class CreateAgencyPipelineStages < ActiveRecord::Migration[7.2]
  def change
    create_table :agency_pipeline_stages do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :agency_pipeline, null: false, foreign_key: { to_table: :agency_pipelines }, index: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.integer :win_probability, null: false, default: 0
      t.boolean :is_won, null: false, default: false
      t.boolean :is_lost, null: false, default: false
      t.jsonb :automation_config, null: false, default: {}
      t.timestamps
    end
  end
end
