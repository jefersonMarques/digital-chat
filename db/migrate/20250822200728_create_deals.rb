# frozen_string_literal: true

class CreateDeals < ActiveRecord::Migration[7.0]
  def change
    create_table :deals do |t|
      t.bigint :account_id, null: false
      t.bigint :deal_pipeline_id, null: false
      t.bigint :deal_stage_id, null: false

      t.bigint :contact_id
      t.bigint :inbox_id
      t.bigint :conversation_id
      t.bigint :owner_id # users.id

      t.string  :title, null: false
      t.integer :amount_cents, null: false, default: 0
      t.string  :currency, null: false, default: "BRL", limit: 3

      t.string  :status, null: false, default: "open" # open|won|lost|archived
      t.string  :source
      t.jsonb   :custom_fields, null: false, default: {}
      t.datetime :closed_at

      t.timestamps
    end

    add_index :deals, :account_id
    add_index :deals, :deal_pipeline_id
    add_index :deals, :deal_stage_id
    add_index :deals, :contact_id
    add_index :deals, :owner_id
    add_index :deals, :status
    add_index :deals, :created_at
    add_index :deals, :custom_fields, using: :gin

    add_foreign_key :deals, :accounts, on_delete: :cascade
    add_foreign_key :deals, :deal_pipelines, on_delete: :cascade
    add_foreign_key :deals, :deal_stages, on_delete: :cascade

    add_foreign_key :deals, :contacts, on_delete: :nullify
    add_foreign_key :deals, :users, column: :owner_id, on_delete: :nullify
    add_foreign_key :deals, :inboxes, on_delete: :nullify
    add_foreign_key :deals, :conversations, on_delete: :nullify

    add_check_constraint :deals, "amount_cents >= 0", name: "deals_amount_cents_non_negative"
    add_check_constraint :deals, "char_length(currency) = 3", name: "deals_currency_len_3"
    add_check_constraint :deals, "status IN ('open','won','lost','archived')", name: "deals_status_enum"
  end
end
