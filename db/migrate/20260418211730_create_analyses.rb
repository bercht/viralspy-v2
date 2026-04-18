class CreateAnalyses < ActiveRecord::Migration[7.1]
  def change
    create_table :analyses do |t|
      t.references :account, null: false, foreign_key: true
      t.references :competitor, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.string :scraping_provider
      t.string :scraping_run_id
      t.jsonb :raw_data, default: {}, null: false
      t.jsonb :profile_metrics, default: {}, null: false
      t.jsonb :insights, default: {}, null: false
      t.integer :posts_scraped_count, default: 0, null: false
      t.integer :posts_analyzed_count, default: 0, null: false
      t.text :error_message
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    add_index :analyses, [:account_id, :created_at]
    add_index :analyses, :status
  end
end
