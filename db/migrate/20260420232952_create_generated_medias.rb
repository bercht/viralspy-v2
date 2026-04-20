class CreateGeneratedMedias < ActiveRecord::Migration[7.1]
  def change
    create_table :generated_medias do |t|
      t.references :account, null: false, foreign_key: true
      t.references :content_suggestion, null: false, foreign_key: true
      t.string :provider, null: false, default: "heygen"
      t.integer :media_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.text :prompt_sent
      t.jsonb :provider_params, default: {}
      t.string :provider_job_id
      t.string :output_url
      t.integer :duration_seconds
      t.integer :cost_cents
      t.text :error_message
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps

      t.index [ :account_id, :created_at ]
      t.index :status
      t.index :provider_job_id
    end
  end
end
