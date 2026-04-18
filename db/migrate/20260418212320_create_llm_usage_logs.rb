class CreateLlmUsageLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :llm_usage_logs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :analysis, foreign_key: true
      t.string :provider, null: false
      t.string :model, null: false
      t.string :use_case
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :cost_cents

      t.timestamps
    end

    add_index :llm_usage_logs, [:account_id, :created_at]
  end
end
