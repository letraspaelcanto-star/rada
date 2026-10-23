# frozen_string_literal: true

class CreateAgencyPipelines < ActiveRecord::Migration[7.2]
  def change
    create_table :agency_pipelines do |t|
      t.references :account, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.text :description
      t.integer :position, null: false, default: 0
      t.timestamps
    end
  end
end
