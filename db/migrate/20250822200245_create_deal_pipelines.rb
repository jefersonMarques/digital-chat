# frozen_string_literal: true

class CreateDealPipelines < ActiveRecord::Migration[7.0]
  def change
    create_table :deal_pipelines do |t|
      t.bigint :account_id, null: false
      t.string :name, null: false
      t.boolean :is_default, null: false, default: false
      t.integer :position, null: false, default: 1
      t.timestamps
    end

    add_index :deal_pipelines, [:account_id, :name], unique: true
    add_index :deal_pipelines, [:account_id, :position]
    add_foreign_key :deal_pipelines, :accounts
  end
end
