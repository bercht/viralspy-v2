class CreatePlaybookVersions < ActiveRecord::Migration[7.1]
  def change
    create_table :playbook_versions do |t|
      t.references :playbook, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.text :content, null: false
      t.text :diff_summary
      t.integer :feedbacks_incorporated_count, null: false, default: 0
      t.bigint :triggered_by_analysis_id

      t.timestamps
    end

    add_index :playbook_versions, [ :playbook_id, :version_number ], unique: true
    add_index :playbook_versions, :triggered_by_analysis_id
  end
end
