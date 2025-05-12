# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_address_ip_pools
#
#  id            :bigint           not null, primary key
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ip_address_id :integer          not null
#  ip_pool_id    :integer          not null
#
# Indexes
#
#  fk_rails_248cc7b695                                        (ip_pool_id)
#  index_ip_address_ip_pools_on_ip_address_id_and_ip_pool_id  (ip_address_id,ip_pool_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ip_address_id => ip_addresses.id)
#  fk_rails_...  (ip_pool_id => ip_pools.id)
#

class IPAddressIPPool < ApplicationRecord
  belongs_to :ip_address
  belongs_to :ip_pool
  
  validates :ip_address_id, uniqueness: { scope: :ip_pool_id }
end
