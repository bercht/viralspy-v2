class CreateStoryObservations < ActiveRecord::Migration[7.1]
  def change
    create_table :story_observations do |t|
      t.references :account,    null: false, foreign_key: true
      t.references :competitor, null: false, foreign_key: true
      t.date :observed_on, null: false
      t.string :format
      t.string :theme
      t.text :description
      t.string :perceived_engagement
      t.text :notes
      t.timestamps
    end

    add_index :story_observations, [:competitor_id, :observed_on]
  end
end
