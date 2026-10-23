# frozen_string_literal: true

class CreateAgencyDealActivities < ActiveRecord::Migration[7.2]
  def change
    create_table :agency_deal_activities do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.references :agency_deal, null: false, foreign_key: { to_table: :agency_deals }, index: true
      t.integer :actor_type, null: false, default: 0
      t.bigint :actor_id
      t.integer :kind, null: false, default: 0
      t.text :body
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
  end
end
