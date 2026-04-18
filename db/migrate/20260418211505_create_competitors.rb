class CreateCompetitors < ActiveRecord::Migration[7.1]
  def change
    create_table :competitors do |t|
      t.references :account, null: false, foreign_key: true
      t.string :instagram_handle, null: false
      t.string :full_name
      t.text :bio
      t.integer :followers_count
      t.integer :following_count
      t.integer :posts_count
      t.string :profile_pic_url
      t.datetime :last_scraped_at

      t.timestamps
    end

    add_index :competitors, [:account_id, :instagram_handle], unique: true
  end
end
