# frozen_string_literal: true

# == Schema Information
#
# Table name: ip_addresses
#
#  id         :integer          not null, primary key
#  hostname   :string(255)
#  ipv4       :string(255)
#  ipv6       :string(255)
#  priority   :integer
#  created_at :datetime
#  updated_at :datetime
#

class IPAddress < ApplicationRecord

  has_many :ip_address_ip_pools, dependent: :destroy
  has_many :ip_pools, through: :ip_address_ip_pools
  has_many :email_ip_mappings, dependent: :destroy

  def ipv4_with_pool_names
    pool_names = ip_pools.map(&:name).join(", ")
    "#{ipv4} (#{pool_names})"
  end

  # For backward compatibility
  def ipv4_with_pool_name
    ipv4_with_pool_names
  end

  # For backward compatibility
  def ip_pool
    ip_pools.first
  end

  validates :ipv4, presence: true, uniqueness: true
  validates :hostname, presence: true
  validates :ipv6, uniqueness: { allow_blank: true }
  validates :priority, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100, only_integer: true }

  scope :order_by_priority, -> { order(priority: :desc) }

  before_validation :set_default_priority

  private

  def set_default_priority
    return if priority.present?

    self.priority = 100
  end

  class << self

    def select_by_priority
      order(Arel.sql("RAND() * priority DESC")).first
    end

  end

end
