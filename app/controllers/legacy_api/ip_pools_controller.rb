module LegacyAPI
  class IPPoolsController < BaseController

    def index
      # Get all IP pools available to this server's organization
      ip_pools = @current_credential.server.organization.ip_pools

      # Format IP pool data
      ip_pool_data = ip_pools.map do |pool|
        {
          id: pool.id,
          uuid: pool.uuid,
          name: pool.name,
          default: pool.default,
          created_at: pool.created_at,
          ip_addresses: pool.ip_addresses.map do |ip|
            {
              id: ip.id,
              ipv4: ip.ipv4,
              ipv6: ip.ipv6,
              hostname: ip.hostname,
              priority: ip.priority
            }
          end
        }
      end

      render_success(ip_pools: ip_pool_data)
    end

    def create
      # Validate parameters
      if params[:name].blank?
        return render_error("ParameterError", "Missing required parameter 'name'")
      end

      if params[:ips].blank? || !params[:ips].is_a?(Array)
        return render_error("ParameterError", "Missing or invalid 'ips' parameter (must be an array)")
      end

      ActiveRecord::Base.transaction do
        # Create the IP pool
        ip_pool = IPPool.new(name: params[:name])

        # Save the IP pool
        unless ip_pool.save
          return render_error("ValidationError", ip_pool.errors.full_messages.join(", "))
        end

        # Associate the pool with the organization
        @current_credential.server.organization.ip_pools << ip_pool

        # Process IP addresses
        ip_errors = []
        processed_ips = []

        params[:ips].each do |ip_address|
          # Check if IP already exists
          existing_ip = IPAddress.find_by(ipv4: ip_address)

          if existing_ip
            # Add existing IP to the pool if not already in it
            unless ip_pool.ip_addresses.include?(existing_ip)
              ip_pool.ip_addresses << existing_ip
            end
            processed_ips << existing_ip
          else
            # Create new IP address
            new_ip = IPAddress.new(
              ipv4: ip_address,
              hostname: "#{ip_address.gsub('.', '-')}.#{@current_credential.server.organization.permalink}.postal"
            )

            if new_ip.save
              ip_pool.ip_addresses << new_ip
              processed_ips << new_ip
            else
              ip_errors << "#{ip_address}: #{new_ip.errors.full_messages.join(', ')}"
            end
          end
        end

        # Return result with warnings for any IP errors
        render_success({
          ip_pool: {
            id: ip_pool.id,
            uuid: ip_pool.uuid,
            name: ip_pool.name,
            created_at: ip_pool.created_at,
            ip_addresses: processed_ips.map do |ip|
              {
                id: ip.id,
                ipv4: ip.ipv4,
                hostname: ip.hostname
              }
            end
          },
          warnings: ip_errors.presence
        })
      end
    rescue => e
      render_error("InternalError", "An error occurred while creating the IP pool: #{e.message}")
    end
  end
end