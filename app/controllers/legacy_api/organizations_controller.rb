# frozen_string_literal: true

module LegacyAPI
  class OrganizationsController < BaseController
    def index
      # Get all organizations
      organizations = Organization.present.order(:name)
      
      # Format the response
      org_data = organizations.map do |org|
        format_organization_data(org, include_basic_details: true)
      end
      
      render_success(organizations: org_data)
    end
    
    def show
      # Get the organization UUID from the parameters
      org_uuid = api_params["uuid"]
      
      # Validate parameters
      if org_uuid.blank?
        render_parameter_error("uuid is required")
        return
      end
      
      # Find the organization
      organization = Organization.present.find_by_uuid(org_uuid)
      if organization.nil?
        render_error "InvalidOrganization", message: "The organization could not be found with the provided UUID"
        return
      end
      
      # Format the response with detailed information
      org_data = format_organization_data(organization, include_details: true)
      
      render_success(organization: org_data)
    end
    
    private
    
    def format_organization_data(organization, options = {})
      data = {
        uuid: organization.uuid,
        name: organization.name,
        permalink: organization.permalink,
        created_at: organization.created_at,
        updated_at: organization.updated_at,
        suspended: organization.suspended?
      }
      
      if options[:include_details]
        # Add more detailed information for show endpoint
        data.merge!({
          time_zone: organization.time_zone,
          owner: {
            id: organization.owner&.id,
            email_address: organization.owner&.email_address,
            name: organization.owner&.name
          },
          servers_count: organization.servers.count,
          ip_pools: organization.ip_pools.map { |pool| { id: pool.id, name: pool.name } }
        })
        
        # Add servers if requested
        if api_params["include_servers"]
          data[:servers] = organization.servers.map do |server|
            {
              uuid: server.uuid,
              name: server.name,
              permalink: server.permalink,
              mode: server.mode,
              created_at: server.created_at
            }
          end
        end
      end
      
      data
    end
  end
end