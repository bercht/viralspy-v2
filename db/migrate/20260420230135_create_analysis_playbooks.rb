class CreateAnalysisPlaybooks < ActiveRecord::Migration[7.1]
  def change
    create_table :analysis_playbooks do |t|
      t.references :analysis, null: false, foreign_key: true
      t.references :playbook, null: false, foreign_key: true
      t.integer :update_status, null: false, default: 0

      t.timestamps
    end

    add_index :analysis_playbooks, [ :analysis_id, :playbook_id ], unique: true
    add_index :analysis_playbooks, :update_status
  end
end
