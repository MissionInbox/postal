class CreateEmailIPMappings < ActiveRecord::Migration[7.0]
  def change
    create_table :email_ip_mappings do |t|
      t.integer :server_id, null: false
      t.string :email_address, null: false
      t.integer :ip_address_id, null: false
      t.timestamps
      
      t.index [:server_id, :email_address], unique: true
    end
    
    add_foreign_key :email_ip_mappings, :servers
    add_foreign_key :email_ip_mappings, :ip_addresses
  end
end