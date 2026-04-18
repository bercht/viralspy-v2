class CreateContentSuggestions < ActiveRecord::Migration[7.1]
  def change
    create_table :content_suggestions do |t|
      t.references :analysis, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.integer :position, null: false
      t.integer :content_type, null: false
      t.string :hook
      t.text :caption_draft
      t.jsonb :format_details, default: {}, null: false
      t.string :suggested_hashtags, array: true, default: [], null: false
      t.text :rationale
      t.integer :status, default: 0, null: false

      t.timestamps
    end

    add_index :content_suggestions, [:account_id, :created_at]
    add_index :content_suggestions, [:analysis_id, :content_type]
    add_index :content_suggestions, [:analysis_id, :position], unique: true
  end
end
