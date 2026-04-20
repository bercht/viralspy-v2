class CreatePromptTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :prompt_templates do |t|
      t.string :use_case, null: false
      t.integer :version, null: false
      t.text :system_content, null: false
      t.text :user_content_erb, null: false
      t.boolean :active, default: false, null: false
      t.text :change_notes

      t.timestamps

      t.index [ :use_case, :version ], unique: true
      t.index [ :use_case, :active ]
    end
  end
end
