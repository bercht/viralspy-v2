class CreateTranscriptionUsageLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :transcription_usage_logs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :post, foreign_key: true
      t.references :analysis, foreign_key: true
      t.string :provider, null: false
      t.string :model, null: false
      t.integer :audio_duration_seconds
      t.integer :cost_cents

      t.timestamps
    end

    add_index :transcription_usage_logs, [:account_id, :created_at]
  end
end
