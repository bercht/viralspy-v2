class CreateOwnPosts < ActiveRecord::Migration[7.1]
  def change
    create_table :own_posts do |t|
      t.references :account,     null: false, foreign_key: true
      t.references :own_profile, null: false, foreign_key: true
      t.string :instagram_post_id
      t.string :post_type, null: false
      t.string :permalink
      t.text :caption
      t.text :transcript
      t.integer :transcript_status, default: 0, null: false
      t.datetime :posted_at
      t.references :inspired_by_suggestion,
        foreign_key: { to_table: :content_suggestions },
        null: true
      t.text :execution_notes
      t.jsonb :metrics, default: {}, null: false
      t.datetime :metrics_last_fetched_at
      t.jsonb :metrics_history, default: [], null: false
      t.integer :performance_rating
      t.text :performance_notes
      t.timestamps
    end

    add_index :own_posts, [:account_id, :posted_at]
    add_index :own_posts, [:own_profile_id, :posted_at]
    add_index :own_posts, :instagram_post_id
  end
end
