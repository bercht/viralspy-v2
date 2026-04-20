class MediaGenerationUsageLog < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account
  belongs_to :generated_media

  validates :provider, presence: true
end
