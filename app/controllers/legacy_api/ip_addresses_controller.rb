module LegacyAPI
  class IPAddressesController < BaseController

    def index
      # Get all IP addresses assigned to this server
      ip_addresses = []
      
      # Add IP addresses from the server's IP pool
      if @current_credential.server.ip_pool
        ip_addresses += @current_credential.server.ip_pool.ip_addresses
      end
      
      # Add IP addresses from IP pool rules
      @current_credential.server.ip_pool_rules.each do |rule|
        if rule.ip_pool && rule.ip_pool.ip_addresses
          rule.ip_pool.ip_addresses.each do |ip|
            ip_addresses << ip unless ip_addresses.include?(ip)
          end
        end
      end
      
      # Deduplicate the list
      ip_addresses.uniq!
      
      # Format IP address data
      ip_address_data = ip_addresses.map do |ip|
        {
          ipv4: ip.ipv4,
          ipv6: ip.ipv6,
          hostname: ip.hostname,
          priority: ip.priority
        }
      end
      
      render_success(ip_addresses: ip_address_data)
    end
  end
end