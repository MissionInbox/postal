# == Schema Information
#
# Table name: email_ip_mappings
#
#  id            :bigint           not null, primary key
#  email_address :string(255)      not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ip_address_id :integer          not null
#  server_id     :integer          not null
#
# Indexes
#
#  fk_rails_4b6b5d59f6                                     (ip_address_id)
#  index_email_ip_mappings_on_server_id_and_email_address  (server_id,email_address) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ip_address_id => ip_addresses.id)
#  fk_rails_...  (server_id => servers.id)
#
class EmailIPMapping < ApplicationRecord
  belongs_to :server
  belongs_to :ip_address
  
  validates :email_address, presence: true
  validates :email_address, uniqueness: { scope: :server_id }
  validate :ip_address_belongs_to_server_organization
  
  private
  
  def ip_address_belongs_to_server_organization
    return if ip_address.ip_pool.organizations.include?(server.organization)
    errors.add(:ip_address, "must belong to the server's organization")
  end
end
