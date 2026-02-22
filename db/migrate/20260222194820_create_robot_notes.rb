class CreateRobotNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :robot_notes do |t|
      t.string :robot_name, null: false

      t.timestamps
    end

    add_index :robot_notes, :robot_name, unique: true
  end
end
