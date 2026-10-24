class AddUniqueActiveParticipantIndex < ActiveRecord::Migration[8.1]
  def change
    add_index :participants, :user_id, unique: true, where: "left_at IS NULL", name: "index_participants_on_user_id_active"
  end
end
