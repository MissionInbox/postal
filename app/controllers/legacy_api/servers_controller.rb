# frozen_string_literal: true

module LegacyAPI
  class ServersController < BaseController
    def list
      # Get all servers for the current organization
      servers = @current_credential.server.organization.servers.present.order(:name)
      
      # Format the response
      server_data = servers.map do |server|
        {
          uuid: server.uuid,
          name: server.name,
          permalink: server.permalink,
          mode: server.mode,
          suspended: server.suspended?,
          privacy_mode: server.privacy_mode,
          ip_pool_id: server.ip_pool_id,
          created_at: server.created_at,
          updated_at: server.updated_at,
          domains_count: server.domains.count,
          credentials_count: server.credentials.count,
          webhooks_count: server.webhooks.count,
          routes_count: server.routes.count
        }
      end
      
      render_success(servers: server_data)
    end
    
    def show
      # Use the server associated with the current credential
      server = @current_credential.server

      # Format the response with more detailed information
      server_data = {
        uuid: server.uuid,
        name: server.name,
        permalink: server.permalink,
        mode: server.mode,
        suspended: server.suspended?,
        suspension_reason: server.suspension_reason,
        privacy_mode: server.privacy_mode,
        ip_pool_id: server.ip_pool_id,
        created_at: server.created_at,
        updated_at: server.updated_at,
        domains_count: server.domains.count,
        credentials_count: server.credentials.count,
        webhooks_count: server.webhooks.count,
        routes_count: server.routes.count,
        organization: {
          uuid: server.organization.uuid,
          name: server.organization.name,
          permalink: server.organization.permalink
        }
      }
      
      # Add stats if requested or if include_stats is not explicitly set to false
      # (keeping backward compatibility by including stats by default)
      if api_params["include_stats"] != false
        server_data[:stats] = {
          messages_sent_today: server.message_db.messages(where: { timestamp: { greater_than_or_equal_to: 1.day.ago.to_f } }, count: true),
          messages_sent_this_month: server.message_db.messages(where: { timestamp: { greater_than_or_equal_to: 1.month.ago.to_f } }, count: true)
        }
      end
      
      # Add domains if requested
      if api_params["include_domains"]
        server_data[:domains] = server.domains.map do |domain|
          {
            uuid: domain.uuid,
            name: domain.name,
            verified: domain.verified?,
            verification_method: domain.verification_method,
            dns_checked_at: domain.dns_checked_at,
            created_at: domain.created_at,
            updated_at: domain.updated_at
          }
        end
      end
      
      render_success(server: server_data)
    end
    
    def create
      # Get the parameters
      org_uuid = api_params["organization_uuid"]
      name = api_params["name"]
      
      # Validate parameters
      if org_uuid.blank? || name.blank?
        render_parameter_error("organization_uuid and name are required")
        return
      end
      
      # Find the organization
      organization = Organization.present.find_by_uuid(org_uuid)
      if organization.nil?
        render_error "InvalidOrganization", message: "The organization could not be found with the provided UUID"
        return
      end
      
      # Check permission (only allow if credential's organization matches or has admin access)
      unless @current_credential.server.organization == organization || @current_credential.user&.admin?
        render_error "AccessDenied", message: "You don't have permission to create servers for this organization"
        return
      end
      
      # Create the server
      server = organization.servers.build(
        name: name,
        mode: api_params["mode"] || "Live",
        ip_pool_id: api_params["ip_pool_id"],
        # Add optional parameters as needed
        privacy_mode: api_params["privacy_mode"] || false
      )
      
      if server.save
        # Provision the database if needed
        unless api_params["skip_provision_database"]
          server.message_db.provisioner.provision
        end
        
        # Create a default API credential for the server
        api_credential = server.credentials.create(
          type: "API",
          name: "Default API Credential",
          key: SecureRandom.alphanumeric(24).downcase
        )
        
        # Return the new server details along with the API key
        render_success(
          server: {
            uuid: server.uuid,
            name: server.name,
            permalink: server.permalink,
            mode: server.mode,
            created_at: server.created_at,
            organization: {
              uuid: organization.uuid,
              name: organization.name,
              permalink: organization.permalink
            },
            api_key: api_credential.key
          }
        )
      else
        render_error "ValidationError", message: "The server could not be created", errors: server.errors.full_messages
      end
    end
  end
end