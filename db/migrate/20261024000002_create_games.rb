class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.references :game_type, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :state, null: false, default: "lobby"
      t.timestamps
    end
    add_index :games, :name, unique: true
  end
end
