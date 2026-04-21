class CreatePlaybookSuggestions < ActiveRecord::Migration[7.1]
  def change
    create_table :playbook_suggestions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :playbook, null: false, foreign_key: true
      t.string :content_type, null: false
      t.string :hook
      t.text :caption_draft
      t.jsonb :format_details, default: {}
      t.string :suggested_hashtags, array: true, default: []
      t.text :rationale
      t.integer :status, default: 0, null: false
      t.timestamps
    end

    add_index :playbook_suggestions, [ :account_id, :created_at ]
    add_index :playbook_suggestions, [ :playbook_id, :status ]
  end
end
