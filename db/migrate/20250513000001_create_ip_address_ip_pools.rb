class CreateIPAddressIPPools < ActiveRecord::Migration[7.0]
  def change
    # Create the join table
    create_table :ip_address_ip_pools do |t|
      t.integer :ip_address_id, null: false
      t.integer :ip_pool_id, null: false
      t.timestamps

      t.index [:ip_address_id, :ip_pool_id], unique: true
    end

    add_foreign_key :ip_address_ip_pools, :ip_addresses
    add_foreign_key :ip_address_ip_pools, :ip_pools

    # Migrate existing relationships
    execute <<~SQL
      INSERT INTO ip_address_ip_pools (ip_address_id, ip_pool_id, created_at, updated_at)
      SELECT id, ip_pool_id, NOW(), NOW() FROM ip_addresses WHERE ip_pool_id IS NOT NULL
    SQL

    # Remove the old foreign key column
    remove_column :ip_addresses, :ip_pool_id
  end
end