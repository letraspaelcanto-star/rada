# frozen_string_literal: true

class CreateAgencyDeals < ActiveRecord::Migration[7.2]
  def change
    create_table :agency_deals do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :agency_pipeline, null: false, foreign_key: { to_table: :agency_pipelines }, index: true
      t.references :agency_pipeline_stage, null: false, foreign_key: { to_table: :agency_pipeline_stages }, index: true
      t.string :title, null: false
      t.bigint :value_cents, null: false, default: 0
      t.string :currency, null: false, default: 'ARS'
      t.references :contact, null: false, foreign_key: true
      t.references :conversation, foreign_key: true
      t.references :company, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users }
      t.integer :priority, null: false, default: 0
      t.date :expected_close_on
      t.date :closed_on
      t.integer :status, null: false, default: 0
      t.text :lost_reason
      t.jsonb :custom_attributes, null: false, default: {}
      t.datetime :discarded_at
      t.timestamps

      t.index %i[account_id agency_pipeline_stage_id]
      t.index %i[account_id status]
    end
  end
end
