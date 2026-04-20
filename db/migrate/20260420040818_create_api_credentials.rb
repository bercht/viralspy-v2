class CreateApiCredentials < ActiveRecord::Migration[7.1]
  def change
    create_table :api_credentials do |t|
      t.references :account, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :encrypted_api_key, null: false
      t.boolean :active, default: true, null: false
      t.datetime :last_validated_at
      t.integer :last_validation_status, default: 0, null: false
      t.timestamps
    end

    add_index :api_credentials, [:account_id, :provider], unique: true
  end
end
