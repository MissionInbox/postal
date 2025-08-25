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
    
    private
    
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