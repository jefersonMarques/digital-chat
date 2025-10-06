# frozen_string_literal: true

class CreateDealStages < ActiveRecord::Migration[7.0]
  def change
    create_table :deal_stages do |t|
      t.bigint :account_id, null: false
      t.bigint :deal_pipeline_id, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 1
      t.boolean :win_stage, null: false, default: false
      t.boolean :lose_stage, null: false, default: false
      t.integer :probability, null: false, default: 0 # 0..100
      t.timestamps
    end

    add_index :deal_stages, [:deal_pipeline_id, :position]
    add_index :deal_stages, [:account_id, :deal_pipeline_id, :name], unique: true, name: "idx_deal_stages_account_pipeline_name"

    add_foreign_key :deal_stages, :accounts
    add_foreign_key :deal_stages, :deal_pipelines

    # garante 0..100 no Postgres
    add_check_constraint :deal_stages, "probability >= 0 AND probability <= 100", name: "deal_stages_probability_0_100"
  end
end
