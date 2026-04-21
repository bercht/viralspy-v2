class AddAuthorRoleAndTargetAudienceToPlaybooks < ActiveRecord::Migration[7.1]
  def change
    add_column :playbooks, :author_role, :string
    add_column :playbooks, :target_audience, :string
  end
end
