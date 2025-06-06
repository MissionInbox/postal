# frozen_string_literal: true

require "resolv"

module HasDNSChecks

  def dns_ok?
    spf_status == "OK" && dkim_status == "OK" && %w[OK Missing].include?(mx_status) && %w[OK Missing].include?(return_path_status)
  end

  def dns_checked?
    spf_status.present?
  end

  def check_dns(source = :manual)
    check_spf_record
    check_dkim_record
    check_mx_records
    check_return_path_record
    self.dns_checked_at = Time.now
    save!
    if source == :auto && !dns_ok? && owner.is_a?(Server)
      WebhookRequest.trigger(owner, "DomainDNSError", {
        server: owner.webhook_hash,
        domain: name,
        uuid: uuid,
        dns_checked_at: dns_checked_at.to_f,
        spf_status: spf_status,
        spf_error: spf_error,
        dkim_status: dkim_status,
        dkim_error: dkim_error,
        mx_status: mx_status,
        mx_error: mx_error,
        return_path_status: return_path_status,
        return_path_error: return_path_error
      })
    end
    dns_ok?
  end

  #
  # SPF
  #

  def check_spf_record
    result = resolver.txt(name)
    spf_records = result.grep(/\Av=spf1/)
    if spf_records.empty?
      self.spf_status = "Missing"
      self.spf_error = "No SPF record exists for this domain"
    else
      # Get the expected SPF record based on current configuration
      expected_record = spf_record

      # If we're using IP addresses, check if any of them are in the SPF record
      spf_ips = Postal::Config.dns.spf_ips
      if spf_ips.is_a?(Array) && spf_ips.any?
        # Check if each required IP is in the record
        missing_ips = []
        spf_ips.each do |ip|
          mechanism = ip.include?(":") ? "ip6:#{ip}" : "ip4:#{ip}"
          unless spf_records.any? { |record| record.include?(mechanism) }
            missing_ips << mechanism
          end
        end
        
        if missing_ips.empty?
          self.spf_status = "OK"
          self.spf_error = nil
          true
        else
          self.spf_status = "Invalid"
          self.spf_error = "SPF record is missing the following mechanisms: #{missing_ips.join(', ')}"
          false
        end
      else
        # Fall back to checking for the include mechanism
        suitable_spf_records = spf_records.grep(/include:\s*#{Regexp.escape(Postal::Config.dns.spf_include)}/)
        if suitable_spf_records.empty?
          self.spf_status = "Invalid"
          self.spf_error = "An SPF record exists but it doesn't include #{Postal::Config.dns.spf_include}"
          false
        else
          self.spf_status = "OK"
          self.spf_error = nil
          true
        end
      end
    end
  end

  def check_spf_record!
    check_spf_record
    save!
  end

  #
  # DKIM
  #

  def check_dkim_record
    domain = "#{dkim_record_name}.#{name}"
    records = resolver.txt(domain)
    if records.empty?
      self.dkim_status = "Missing"
      self.dkim_error = "No TXT records were returned for #{domain}"
    else
      sanitised_dkim_record = records.first.strip.ends_with?(";") ? records.first.strip : "#{records.first.strip};"
      if records.size > 1
        self.dkim_status = "Invalid"
        self.dkim_error = "There are #{records.size} records for at #{domain}. There should only be one."
      elsif sanitised_dkim_record != dkim_record
        self.dkim_status = "Invalid"
        self.dkim_error = "The DKIM record at #{domain} does not match the record we have provided. Please check it has been copied correctly."
      else
        self.dkim_status = "OK"
        self.dkim_error = nil
        true
      end
    end
  end

  def check_dkim_record!
    check_dkim_record
    save!
  end

  #
  # MX
  #

  def check_mx_records
    records = resolver.mx(name).map(&:last)
    if records.empty?
      self.mx_status = "Missing"
      self.mx_error = "There are no MX records for #{name}"
    else
      missing_records = Postal::Config.dns.mx_records.dup - records.map { |r| r.to_s.downcase }
      if missing_records.empty?
        self.mx_status = "OK"
        self.mx_error = nil
      elsif missing_records.size == Postal::Config.dns.mx_records.size
        self.mx_status = "Missing"
        self.mx_error = "You have MX records but none of them point to us."
      else
        self.mx_status = "Invalid"
        self.mx_error = "MX #{missing_records.size == 1 ? 'record' : 'records'} for #{missing_records.to_sentence} are missing and are required."
      end
    end
  end

  def check_mx_records!
    check_mx_records
    save!
  end

  #
  # Return Path
  #

  def check_return_path_record
    records = resolver.cname(return_path_domain)
    if records.empty?
      self.return_path_status = "Missing"
      self.return_path_error = "There is no return path record at #{return_path_domain}"
    elsif records.size == 1 && records.first == Postal::Config.dns.return_path_domain
      self.return_path_status = "OK"
      self.return_path_error = nil
    else
      self.return_path_status = "Invalid"
      self.return_path_error = "There is a CNAME record at #{return_path_domain} but it points to #{records.first} which is incorrect. It should point to #{Postal::Config.dns.return_path_domain}."
    end
  end

  def check_return_path_record!
    check_return_path_record
    save!
  end

end

# -*- SkipSchemaAnnotations
