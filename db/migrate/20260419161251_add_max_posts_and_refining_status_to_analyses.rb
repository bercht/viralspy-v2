class AddMaxPostsAndRefiningStatusToAnalyses < ActiveRecord::Migration[7.1]
  def up
    add_column :analyses, :max_posts, :integer, null: false, default: 50

    # Remap existing status values: insert refining at 6, push completed 6→7, failed 7→8
    # Order matters: remap 7→8 first, then 6→7 to avoid collision
    execute <<~SQL
      UPDATE analyses
      SET status = CASE status
        WHEN 7 THEN 8
        WHEN 6 THEN 7
        ELSE status
      END
      WHERE status IN (6, 7);
    SQL
  end

  def down
    execute <<~SQL
      UPDATE analyses
      SET status = CASE status
        WHEN 6 THEN 5
        WHEN 7 THEN 6
        WHEN 8 THEN 7
        ELSE status
      END
      WHERE status IN (6, 7, 8);
    SQL

    remove_column :analyses, :max_posts
  end
end
