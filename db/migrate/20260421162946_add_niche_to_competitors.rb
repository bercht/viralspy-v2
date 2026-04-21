class AddNicheToCompetitors < ActiveRecord::Migration[7.1]
  def change
    add_column :competitors, :niche, :string
  end
end
