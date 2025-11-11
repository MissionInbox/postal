# frozen_string_literal: true

module LegacyAPI
  class OrganizationsPublicController < PublicController
    def statistics
      # Get the organization UUID from the parameters
      org_uuid = api_params["uuid"]

      # Validate parameters
      if org_uuid.blank?
        render_parameter_error("organization_uuid is required")
        return
      end

      # Find the organization using the UUID as authentication
      organization = Organization.present.find_by_uuid(org_uuid)
      if organization.nil?
        render_error "InvalidOrganization", message: "The organization could not be found with the provided UUID"
        return
      end

      # Calculate organization statistics
      stats_data = calculate_organization_statistics(organization)

      render_success(statistics: stats_data)
    end

    def ip_allocation
      # Get the organization UUID from the parameters
      org_uuid = api_params["uuid"]

      # Validate parameters
      if org_uuid.blank?
        render_parameter_error("organization_uuid is required")
        return
      end

      # Find the organization using the UUID as authentication
      organization = Organization.present.find_by_uuid(org_uuid)
      if organization.nil?
        render_error "InvalidOrganization", message: "The organization could not be found with the provided UUID"
        return
      end

      # Get IP allocation data with email sending statistics
      allocation_data = get_ip_allocation(organization)

      render_success(allocation_data)
    end
    
    private
    
    def get_ip_allocation(organization)
      # Get all IP addresses belonging to organization's IP pools with their IP pool mappings
      ip_addresses_data = organization.ip_pools.includes(:ip_addresses).flat_map(&:ip_addresses).uniq.map do |ip|
        pool_names = ip.ip_pools.where(id: organization.ip_pools.pluck(:id)).pluck(:name)
        {
          ipv4: ip.ipv4,
          ipv6: ip.ipv6,
          hostname: ip.hostname,
          priority: ip.priority,
          ip_pools: pool_names,
          emails_sent: count_emails_for_ip(ip)
        }
      end

      # Get all IP pools with their server mappings (filtered by organization)
      ip_pools_data = organization.ip_pools.includes(:servers).map do |pool|
        server_names = pool.servers.where(organization_id: organization.id).pluck(:name)
        {
          name: pool.name,
          uuid: pool.uuid,
          default: pool.default,
          servers: server_names,
          emails_sent: count_emails_for_ip_pool(pool)
        }
      end

      # Get all servers with their IP pool and IP address mappings (filtered by organization)
      servers_data = organization.servers.includes(ip_pool: :ip_addresses).map do |server|
        if server.ip_pool
          ip_addresses = server.ip_pool.ip_addresses.any? ? server.ip_pool.ip_addresses.pluck(:ipv4) : []
          {
            name: server.name,
            uuid: server.uuid,
            ip_pool: server.ip_pool.name,
            ip_addresses: ip_addresses,
            emails_sent: count_emails_for_server(server)
          }
        else
          {
            name: server.name,
            uuid: server.uuid,
            ip_pool: nil,
            ip_addresses: [],
            emails_sent: count_emails_for_server(server)
          }
        end
      end

      {
        organization: {
          uuid: organization.uuid,
          name: organization.name
        },
        ip_addresses: ip_addresses_data,
        ip_pools: ip_pools_data,
        servers: servers_data
      }
    end

    # Count total emails sent through a specific IP address
    def count_emails_for_ip(ip_address)
      QueuedMessage.where(ip_address_id: ip_address.id).count
    end

    # Count total emails sent through an IP pool
    def count_emails_for_ip_pool(ip_pool)
      ip_address_ids = ip_pool.ip_addresses.pluck(:id)
      return 0 if ip_address_ids.empty?

      QueuedMessage.where(ip_address_id: ip_address_ids).count
    end

    # Count total emails sent through a server
    def count_emails_for_server(server)
      # Get total outgoing messages from the server's message database
      server.message_db.messages(where: { scope: "outgoing" }, count: true)
    rescue StandardError => e
      # Return 0 if there's an error accessing the message database
      0
    end

    def calculate_organization_statistics(organization)
      servers = organization.servers
      
      # Initialize statistics
      overall_message_rate = 0.0
      total_queued_count = 0
      total_sent = 0
      server_stats = []
      
      # Get organization IP addresses
      ip_addresses = organization.ip_pools.includes(:ip_addresses).flat_map(&:ip_addresses)
      
      # Calculate statistics for each server
      servers.each do |server|
        # Get server message rate (messages per second over last 60 seconds)
        server_message_rate = server.message_rate
        overall_message_rate += server_message_rate
        
        # Get queued message count for this server
        queued_count = server.queued_messages.ready.count
        total_queued_count += queued_count
        
        # Get total sent messages (outgoing messages in last 60 seconds)
        sent_count = server.message_db.live_stats.total(60, types: [:outgoing])
        total_sent += sent_count
        
        # Add server statistics
        server_stats << {
          uuid: server.uuid,
          name: server.name,
          queued_count: queued_count,
          message_rate: server_message_rate,
          sent_count: sent_count
        }
      end
      
      # Format response
      {
        uuid: organization.uuid,
        name: organization.name,
        overall_message_rate: overall_message_rate,
        total_queued_count: total_queued_count,
        total_sent: total_sent,
        servers_count: servers.count,
        ip_addresses_count: ip_addresses.count,
        ip_addresses: ip_addresses.map do |ip|
          {
            id: ip.id,
            ipv4: ip.ipv4,
            ipv6: ip.ipv6,
            hostname: ip.hostname,
            priority: ip.priority
          }
        end,
        servers: server_stats
      }
    end
  end
end