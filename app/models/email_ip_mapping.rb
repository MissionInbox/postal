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
  
  # Match email against a mapping, supporting wildcards
  # @param [String] email The email address to match
  # @return [EmailIPMapping, nil] The matching mapping or nil
  def self.match_for_email(server, email)
    return nil if email.blank? || server.nil?
    
    # First try exact match
    exact_match = server.email_ip_mappings.find_by(email_address: email)
    return exact_match if exact_match
    
    # Try wildcard match for domain
    if email.include?('@')
      domain = email.split('@').last
      wildcard = "*@#{domain}"
      server.email_ip_mappings.find_by(email_address: wildcard)
    else
      nil
    end
  end
  
  private
  
  def ip_address_belongs_to_server_organization
    return if ip_address.ip_pools.any? { |pool| pool.organizations.include?(server.organization) }
    errors.add(:ip_address, "must belong to at least one IP pool in the server's organization")
  end
end
