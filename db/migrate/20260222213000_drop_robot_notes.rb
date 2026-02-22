class DropRobotNotes < ActiveRecord::Migration[8.1]
  def up
    drop_table :robot_notes, if_exists: true
  end

  def down
    create_table :robot_notes do |t|
      t.string :robot_name

      t.timestamps
    end

    add_index :robot_notes, :robot_name, unique: true
  end
end
