# frozen_string_literal: true

class AddPriorityToQueuedMessages < ActiveRecord::Migration[7.0]
  def change
    add_column :queued_messages, :priority, :integer, default: 0
    add_index :queued_messages, :priority
  end
end