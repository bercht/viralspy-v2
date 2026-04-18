class Account < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :competitors, dependent: :destroy
  has_many :analyses, dependent: :destroy

  validates :name, presence: true
end
