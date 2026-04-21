class AddAccountIdToPlaybookVersions < ActiveRecord::Migration[7.1]
  def change
    return if column_exists?(:playbook_versions, :account_id)

    add_reference :playbook_versions, :account, null: false, foreign_key: true
  end
end
