# frozen_string_literal: true

class DealPipeline < ApplicationRecord
  belongs_to :account

  has_many :deal_stages, dependent: :destroy
  has_many :deals, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validates :is_default, inclusion: { in: [true, false] }

  scope :ordered, -> { order(:position, :id) }

  before_save :ensure_single_default_within_account, if: :will_save_change_to_is_default?

  private

  def ensure_single_default_within_account
    return unless is_default?

    self.class.where(account_id: account_id, is_default: true).where.not(id: id).update_all(is_default: false)
  end
end
