class CreatePlaybooks < ActiveRecord::Migration[7.1]
  def change
    create_table :playbooks do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :niche
      t.text :purpose
      t.integer :current_version_number, null: false, default: 0

      t.timestamps
    end

    add_index :playbooks, [ :account_id, :name ], unique: true
  end
end
