class AddMediaGenerationPreferencesToAccounts < ActiveRecord::Migration[7.1]
  def change
    add_column :accounts, :media_generation_preferences, :jsonb, default: {}, null: false
  end
end
