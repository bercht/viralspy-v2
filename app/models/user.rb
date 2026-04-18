class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  belongs_to :account

  validates :first_name, presence: true
  validates :last_name, presence: true

  def full_name
    [first_name, last_name].compact.join(' ').presence || email
  end
end
