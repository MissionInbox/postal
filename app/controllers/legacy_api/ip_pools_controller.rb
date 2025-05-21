module LegacyAPI
  class IPPoolsController < BaseController
  
    # Get the least used IP pool (for assigning to new servers)
    def least_used
      # Get all IP pools available to this server's organization
      ip_pools = @current_credential.server.organization.ip_pools
      
      # Only consider pools with at least one IP address
      valid_pools = ip_pools.select { |pool| pool.ip_addresses.any? }
      
      if valid_pools.empty?
        return render_error("NoValidIPPools", "No valid IP pools with IP addresses found")
      end
      
      # Sort pools by usage (least to most)
      sorted_pools = valid_pools.sort_by do |pool|
        count = count_messages_for_ip_pool(pool)
        ip_count = pool.ip_addresses.count
        ip_count > 0 ? count.to_f / ip_count : Float::INFINITY
      end
      
      # Get top N least used pools (default to top 3)
      top_n_limit = params[:top_pools_limit].to_i
      top_n_limit = 5 if top_n_limit <= 0  # Default to 3 if not specified or invalid
      top_n = [sorted_pools.size, top_n_limit].min
      
      # Use a timestamp-based index to rotate through the top pools
      pool_index = (Time.now.to_i / 60) % top_n
      least_used_pool = sorted_pools[pool_index]
      
      # Get stats for the pool
      total_sent = count_messages_for_ip_pool(least_used_pool)
      ip_count = least_used_pool.ip_addresses.count
      
      # Build the response
      result = {
        ip_pool: {
          id: least_used_pool.id,
          uuid: least_used_pool.uuid,
          name: least_used_pool.name,
          default: least_used_pool.default,
          created_at: least_used_pool.created_at,
          stats: {
            total_messages_sent: total_sent,
            ip_count: ip_count,
            average_per_ip: ip_count > 0 ? (total_sent / ip_count.to_f).round(2) : 0
          }
        }
      }
      
      render_success(result)
    end

    def index
      # Get all IP pools available to this server's organization
      ip_pools = @current_credential.server.organization.ip_pools

      # Check if we should include stats
      include_stats = params[:include_stats].to_s.downcase == 'true'
      
      # Check if we should find the least used pool
      find_least_used = params[:find_least_used].to_s.downcase == 'true'

      # Format IP pool data
      ip_pool_data = ip_pools.map do |pool|
        # Get all IP addresses for this pool
        ip_addresses_with_stats = pool.ip_addresses.map do |ip|
          ip_data = {
            id: ip.id,
            ipv4: ip.ipv4,
            ipv6: ip.ipv6,
            hostname: ip.hostname,
            priority: ip.priority
          }
          
          # Add stats per IP if requested
          if include_stats
            ip_data[:messages_sent] = count_messages_for_ip(ip)
          end
          
          ip_data
        end
        
        pool_data = {
          id: pool.id,
          uuid: pool.uuid,
          name: pool.name,
          default: pool.default,
          created_at: pool.created_at,
          ip_addresses: ip_addresses_with_stats
        }

        # Add stats if requested
        if include_stats
          total_sent = count_messages_for_ip_pool(pool)
          
          pool_data[:stats] = {
            total_messages_sent: total_sent,
            ip_count: pool.ip_addresses.count,
            average_per_ip: pool.ip_addresses.any? ? (total_sent / pool.ip_addresses.count.to_f).round(2) : 0
          }
        end

        pool_data
      end
      
      # If requested, find and include the least used IP pool
      if find_least_used && include_stats && ip_pools.any?
        # Only consider pools with at least one IP address
        valid_pools = ip_pools.select { |pool| pool.ip_addresses.any? }
        
        if valid_pools.any?
          # Find the pool with the least messages per IP address
          least_used_pool = valid_pools.min_by do |pool|
            count = count_messages_for_ip_pool(pool)
            ip_count = pool.ip_addresses.count
            ip_count > 0 ? count.to_f / ip_count : Float::INFINITY
          end
          
          result = {
            ip_pools: ip_pool_data,
            least_used_pool: {
              id: least_used_pool.id,
              uuid: least_used_pool.uuid,
              name: least_used_pool.name
            }
          }
          
          render_success(result)
          return
        end
      end

      render_success(ip_pools: ip_pool_data)
    end
    
    private
    
    # Count the total number of messages sent through a specific IP pool
    def count_messages_for_ip_pool(ip_pool)
      # Get all IP address IDs associated with this pool
      ip_address_ids = ip_pool.ip_addresses.pluck(:id)
      return 0 if ip_address_ids.empty?
      
      # Use the filtered query based on time period
      filtered_query(QueuedMessage.where(ip_address_id: ip_address_ids)).count
    end
    
    # Count messages sent through a specific IP address
    def count_messages_for_ip(ip_address)
      # Use the filtered query based on time period
      filtered_query(QueuedMessage.where(ip_address_id: ip_address.id)).count
    end
    
    # Apply time period filtering to a query
    def filtered_query(base_query)
      # Get time period from parameters (default to all time)
      period = params[:stats_period].to_s.downcase
      
      # Apply time filtering if specified
      case period
      when 'today'
        base_query = base_query.where('created_at >= ?', Time.current.beginning_of_day)
      when 'yesterday'
        base_query = base_query.where('created_at >= ? AND created_at < ?', 
                                    Time.current.yesterday.beginning_of_day, 
                                    Time.current.beginning_of_day)
      when 'week'
        base_query = base_query.where('created_at >= ?', Time.current.beginning_of_week)
      when 'month'
        base_query = base_query.where('created_at >= ?', Time.current.beginning_of_month)
      when 'year'
        base_query = base_query.where('created_at >= ?', Time.current.beginning_of_year)
      end
      
      base_query
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