# frozen_string_literal: true

class Deal < ApplicationRecord
  STATUSES = %w[open won lost archived].freeze

  belongs_to :account
  belongs_to :deal_pipeline
  belongs_to :deal_stage

  belongs_to :contact, optional: true
  belongs_to :inbox, optional: true
  belongs_to :conversation, optional: true
  belongs_to :owner, class_name: 'User', foreign_key: :owner_id, optional: true

  validates :title, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :currency, presence: true, length: { is: 3 }
  validates :status, inclusion: { in: STATUSES }

  validate  :stage_belongs_to_pipeline
  validate  :account_consistency

  scope :recent, -> { order(created_at: :desc) }
  scope :open,   -> { where(status: 'open') }
  scope :won,    -> { where(status: 'won') }
  scope :lost,   -> { where(status: 'lost') }
  scope :archived, -> { where(status: 'archived') }

  before_validation :fill_missing_foreign_keys

  private

  def fill_missing_foreign_keys
    self.deal_pipeline_id ||= deal_stage&.deal_pipeline_id
    self.account_id       ||= deal_pipeline&.account_id || deal_stage&.account_id
    self.currency           = currency&.upcase if currency.present?
  end

  def stage_belongs_to_pipeline
    return unless deal_stage_id && deal_pipeline_id
    return if deal_stage&.deal_pipeline_id == deal_pipeline_id

    errors.add(:deal_stage_id, 'não pertence ao pipeline informado')
  end

  def account_consistency
    return unless account_id

    if deal_pipeline && deal_pipeline.account_id != account_id
      errors.add(:account_id, 'deve ser o mesmo do pipeline')
    end
    if deal_stage && deal_stage.account_id != account_id
      errors.add(:account_id, 'deve ser o mesmo do stage')
    end
  end
end
