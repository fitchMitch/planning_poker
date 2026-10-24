class CreateParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :participants do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :creator, null: false, default: false
      t.timestamps
    end
  end
end
