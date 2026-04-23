class AddExpiresAtToAnalyses < ActiveRecord::Migration[7.1]
  def change
    add_column :analyses, :expires_at, :datetime
    add_index :analyses, :expires_at
  end
end
