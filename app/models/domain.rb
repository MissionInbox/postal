# frozen_string_literal: true

# == Schema Information
#
# Table name: domains
#
#  id                     :integer          not null, primary key
#  custom_mx_records      :text(65535)
#  dkim_error             :string(255)
#  dkim_identifier_string :string(255)
#  dkim_private_key       :text(65535)
#  dkim_status            :string(255)
#  dmarc_error            :string(255)
#  dmarc_record           :text(65535)
#  dmarc_status           :string(255)
#  dns_checked_at         :datetime
#  incoming               :boolean          default(TRUE)
#  mx_error               :string(255)
#  mx_status              :string(255)
#  name                   :string(255)
#  outgoing               :boolean          default(TRUE)
#  owner_type             :string(255)
#  return_path_error      :string(255)
#  return_path_status     :string(255)
#  spf_error              :string(255)
#  spf_status             :string(255)
#  use_for_any            :boolean
#  uuid                   :string(255)
#  verification_method    :string(255)
#  verification_token     :string(255)
#  verified_at            :datetime
#  created_at             :datetime
#  updated_at             :datetime
#  owner_id               :integer
#  server_id              :integer
#
# Indexes
#
#  index_domains_on_server_id  (server_id)
#  index_domains_on_uuid       (uuid)
#

require "resolv"

class Domain < ApplicationRecord

  include HasUUID

  include HasDNSChecks

  VERIFICATION_EMAIL_ALIASES = %w[webmaster postmaster admin administrator hostmaster].freeze
  VERIFICATION_METHODS = %w[DNS Email].freeze

  belongs_to :server, optional: true
  belongs_to :owner, optional: true, polymorphic: true
  has_many :routes, dependent: :destroy
  has_many :track_domains, dependent: :destroy

  validates :name, presence: true, format: { with: /\A[a-z0-9\-.]*\z/ }, uniqueness: { case_sensitive: false, scope: [:owner_type, :owner_id], message: "is already added" }
  validates :verification_method, inclusion: { in: VERIFICATION_METHODS }

  random_string :dkim_identifier_string, type: :chars, length: 6, unique: true, upper_letters_only: true

  before_create :generate_dkim_key
  before_save :generate_default_dmarc_record

  scope :verified, -> { where.not(verified_at: nil) }

  before_save :update_verification_token_on_method_change

  def verified?
    verified_at.present?
  end

  def mark_as_verified
    return false if verified?

    self.verified_at = Time.now
    save!
  end

  def parent_domains
    parts = name.split(".")
    parts[0, parts.size - 1].each_with_index.map do |_, i|
      parts[i..].join(".")
    end
  end

  def generate_dkim_key
    self.dkim_private_key = OpenSSL::PKey::RSA.new(1024).to_s
  end

  def dkim_key
    return nil unless dkim_private_key

    @dkim_key ||= OpenSSL::PKey::RSA.new(dkim_private_key)
  end

  def to_param
    uuid
  end

  def verification_email_addresses
    parent_domains.map do |domain|
      VERIFICATION_EMAIL_ALIASES.map do |a|
        "#{a}@#{domain}"
      end
    end.flatten
  end

  def spf_record
    # Check if we have specific IP addresses configured
    spf_ips = Postal::Config.dns.spf_ips
    
    if spf_ips.is_a?(Array) && spf_ips.any?
      # Build SPF record with specific IP addresses
      ip_mechanisms = spf_ips.map do |ip|
        if ip.include?(":")
          "ip6:#{ip}"  # IPv6 format
        else
          "ip4:#{ip}"  # IPv4 format
        end
      end
      
      # Return the SPF record with IP mechanisms
      "v=spf1 #{ip_mechanisms.join(' ')} ~all"
    else
      # Fall back to the default include mechanism
      "v=spf1 include:#{Postal::Config.dns.spf_include} ~all"
    end
  end

  def dkim_record
    return if dkim_key.nil?

    public_key = dkim_key.public_key.to_s.gsub(/-+[A-Z ]+-+\n/, "").gsub(/\n/, "")
    "v=DKIM1; t=s; h=sha256; p=#{public_key};"
  end

  def dkim_identifier
    return nil unless dkim_identifier_string

    Postal::Config.dns.dkim_identifier + "-#{dkim_identifier_string}"
  end

  def dkim_record_name
    identifier = dkim_identifier
    return if identifier.nil?

    "#{identifier}._domainkey"
  end

  def return_path_domain
    "#{Postal::Config.dns.custom_return_path_prefix}.#{name}"
  end

  # Returns MX records for this domain. Uses custom MX records if configured,
  # otherwise falls back to global configuration.
  #
  # @return [Array<String>] Array of MX record hostnames
  def mx_records
    if custom_mx_records.present?
      JSON.parse(custom_mx_records)
    else
      Postal::Config.dns.mx_records
    end
  end

  # Sets custom MX records, accepting either an array or JSON string
  #
  # @param value [Array<String>, String] Array of MX hostnames or JSON string
  def custom_mx_records=(value)
    if value.is_a?(Array)
      super(value.to_json)
    else
      super(value)
    end
  end

  # Returns whether DMARC is configured for this domain
  #
  # @return [Boolean]
  def dmarc_enabled?
    dmarc_record.present?
  end

  # Returns the DMARC record name (subdomain)
  #
  # @return [String] DMARC record name
  def dmarc_record_name
    "_dmarc.#{name}"
  end

  # Returns a DNSResolver instance that can be used to perform DNS lookups needed for
  # the verification and DNS checking for this domain.
  #
  # @return [DNSResolver]
  def resolver
    return DNSResolver.local if Postal::Config.postal.use_local_ns_for_domain_verification?

    @resolver ||= DNSResolver.for_domain(name)
  end

  def dns_verification_string
    "#{Postal::Config.dns.domain_verify_prefix} #{verification_token}"
  end

  def verify_with_dns
    return false unless verification_method == "DNS"

    begin
      result = resolver.txt(name)

      if result.include?(dns_verification_string)
        self.verified_at = Time.now
        return save
      end
    rescue => e
      Rails.logger.error "DNS verification error for domain #{name}: #{e.message}"
      return false
    end

    false
  end

  private

  def update_verification_token_on_method_change
    return unless verification_method_changed?

    if verification_method == "DNS"
      self.verification_token = SecureRandom.alphanumeric(32)
    elsif verification_method == "Email"
      self.verification_token = rand(999_999).to_s.ljust(6, "0")
    else
      self.verification_token = nil
    end
  end

  def generate_default_dmarc_record
    # Only generate if dmarc_record is blank (not set by user)
    return if dmarc_record.present?

    # Use abuse@{domain_name} as the reporting email
    report_email = "abuse@#{name}"

    # Generate default DMARC record with quarantine policy
    self.dmarc_record = "v=DMARC1; p=quarantine; rua=mailto:#{report_email}; ruf=mailto:#{report_email}; sp=quarantine; adkim=r; aspf=r; fo=1; ri=864000;"
  end

end
