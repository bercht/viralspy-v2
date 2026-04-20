class Playbook < ApplicationRecord
  acts_as_tenant :account

  belongs_to :account
  has_many :playbook_versions, dependent: :destroy
  has_many :playbook_feedbacks, dependent: :destroy
  has_many :analysis_playbooks, dependent: :destroy
  has_many :analyses, through: :analysis_playbooks

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id, case_sensitive: false }

  scope :recent, -> { order(created_at: :desc) }

  def current_version
    return nil if current_version_number == 0

    playbook_versions.find_by(version_number: current_version_number)
  end

  def current_content
    current_version&.content || initial_content
  end

  def initial_content
    lines = [ "# Playbook — #{name}" ]
    lines << "\n## Nicho e Contexto\n#{niche}" if niche.present?
    lines << "\n## Propósito\n#{purpose}" if purpose.present?
    lines << "\n## Padrões de Conteúdo\n\n_Ainda não há dados suficientes. Este playbook será atualizado após a primeira análise._"
    lines.join("\n")
  end
end
