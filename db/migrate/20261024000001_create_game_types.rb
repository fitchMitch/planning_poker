class CreateGameTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :game_types do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description, null: false
      t.timestamps
    end
    add_index :game_types, :name, unique: true
    add_index :game_types, :slug, unique: true
  end
end
