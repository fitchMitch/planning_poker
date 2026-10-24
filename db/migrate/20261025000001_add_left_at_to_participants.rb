class AddLeftAtToParticipants < ActiveRecord::Migration[8.1]
  def change
    add_column :participants, :left_at, :datetime
  end
end
