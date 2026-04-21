class CreateOwnProfiles < ActiveRecord::Migration[7.1]
  def change
    create_table :own_profiles do |t|
      t.references :account, null: false, foreign_key: true
      t.string :instagram_handle, null: false
      t.string :full_name
      t.text :bio
      t.text :voice_notes
      t.text :meta_access_token
      t.datetime :meta_token_expires_at
      t.datetime :meta_token_last_refreshed_at
      t.timestamps
    end

    add_index :own_profiles, [:account_id, :instagram_handle], unique: true
  end
end
