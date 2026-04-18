class CreatePosts < ActiveRecord::Migration[7.1]
  def change
    create_table :posts do |t|
      t.references :analysis, null: false, foreign_key: true
      t.references :competitor, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.string :instagram_post_id, null: false
      t.string :shortcode
      t.integer :post_type, null: false
      t.text :caption
      t.string :display_url
      t.string :video_url
      t.integer :likes_count, default: 0, null: false
      t.integer :comments_count, default: 0, null: false
      t.integer :video_view_count
      t.string :hashtags, array: true, default: [], null: false
      t.string :mentions, array: true, default: [], null: false
      t.datetime :posted_at

      t.decimal :quality_score, precision: 10, scale: 4
      t.boolean :selected_for_analysis, default: false, null: false

      t.text :transcript
      t.integer :transcript_status, default: 0, null: false
      t.datetime :transcribed_at

      t.timestamps
    end

    add_index :posts, [:account_id, :posted_at]
    add_index :posts, :instagram_post_id
    add_index :posts, [:analysis_id, :selected_for_analysis]
    add_index :posts, [:analysis_id, :post_type, :quality_score]
  end
end
