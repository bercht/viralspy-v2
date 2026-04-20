class AddLLMPreferencesToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :llm_preferences, :jsonb, default: {}, null: false
  end
end
