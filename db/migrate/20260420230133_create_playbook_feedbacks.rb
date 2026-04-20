class CreatePlaybookFeedbacks < ActiveRecord::Migration[7.1]
  def change
    create_table :playbook_feedbacks do |t|
      t.references :account, null: false, foreign_key: true
      t.references :playbook, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :status, null: false, default: 0
      t.integer :source, null: false, default: 0
      t.bigint :incorporated_in_version

      t.timestamps
    end

    add_index :playbook_feedbacks, :status
    add_index :playbook_feedbacks, :incorporated_in_version
  end
end
