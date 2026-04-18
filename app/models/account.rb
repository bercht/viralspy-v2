class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :competitors, dependent: :destroy
  has_many :analyses, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :content_suggestions, dependent: :destroy
  has_many :llm_usage_logs, dependent: :nullify
  has_many :transcription_usage_logs, dependent: :nullify

  validates :name, presence: true
end
