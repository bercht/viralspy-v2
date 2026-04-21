class CreateMediaGenerationUsageLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :media_generation_usage_logs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :generated_media, null: false, foreign_key: { to_table: :generated_medias }
      t.string :provider, null: false
      t.integer :duration_seconds
      t.integer :cost_cents
      t.timestamps

      t.index [ :account_id, :created_at ]
    end
  end
end
