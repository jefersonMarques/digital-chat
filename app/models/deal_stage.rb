# frozen_string_literal: true

class DealStage < ApplicationRecord
  belongs_to :account
  belongs_to :deal_pipeline

  has_many :deals, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { scope: %i[account_id deal_pipeline_id] }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :probability, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate  :win_and_lose_cannot_be_true_together

  scope :ordered, -> { order(:position, :id) }
  scope :wins,     -> { where(win_stage: true) }
  scope :losses,   -> { where(lose_stage: true) }

  private

  def win_and_lose_cannot_be_true_together
    return unless win_stage && lose_stage

    errors.add(:base, 'win_stage e lose_stage não podem ser verdadeiros ao mesmo tempo')
  end
end
