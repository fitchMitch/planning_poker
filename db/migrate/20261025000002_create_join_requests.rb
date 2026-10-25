class CreateJoinRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :join_requests do |t|
      t.references :game, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
  end
end
