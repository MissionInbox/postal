# frozen_string_literal: true

module LegacyAPI
  class ServersPublicController < PublicController
    def create
      # Get the parameters
      org_uuid = api_params["organization_uuid"]
      name = api_params["name"]
      
      # Validate parameters
      if org_uuid.blank? || name.blank?
        render_parameter_error("organization_uuid and name are required")
        return
      end
      
      # Find the organization using the UUID as authentication
      organization = Organization.present.find_by_uuid(org_uuid)
      if organization.nil?
        render_error "InvalidOrganization", message: "The organization could not be found with the provided UUID"
        return
      end
      
      # Check if server with the same name already exists in this organization
      existing_server = organization.servers.present.find_by(name: name)
      if existing_server
        # Check if server already has an API credential
        api_credential = existing_server.credentials.where(type: "API").first
        
        # If no API credential exists, create one
        if api_credential.nil?
          api_credential = existing_server.credentials.create(
            type: "API",
            name: "Default API Credential",
            key: SecureRandom.alphanumeric(24).downcase
          )
        end
        
        # Return the existing server details with API key
        render_success(
          server: {
            uuid: existing_server.uuid,
            name: existing_server.name,
            permalink: existing_server.permalink,
            mode: existing_server.mode,
            created_at: existing_server.created_at,
            organization: {
              uuid: organization.uuid,
              name: organization.name,
              permalink: organization.permalink
            },
            api_key: api_credential.key,
            already_exists: true
          }
        )
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
            api_key: api_credential.key,
            already_exists: false
          }
        )
      else
        render_error "ValidationError", message: "The server could not be created", errors: server.errors.full_messages
      end
    end
    
    def delete
      # Get the parameters
      server_uuid = api_params["server_uuid"]
      org_uuid = api_params["organization_uuid"]
      
      # Validate parameters
      if server_uuid.blank? || org_uuid.blank?
        render_parameter_error("server_uuid and organization_uuid are required")
        return
      end
      
      # Find the organization using the UUID as authentication
      organization = Organization.present.find_by_uuid(org_uuid)
      if organization.nil?
        render_error "InvalidOrganization", message: "The organization could not be found with the provided UUID"
        return
      end
      
      # Find the server
      server = organization.servers.present.find_by_uuid(server_uuid)
      if server.nil?
        render_error "InvalidServer", message: "The server could not be found with the provided server_uuid"
        return
      end
      
      # Soft delete the server (using HasSoftDestroy module)
      if server.soft_destroy
        render_success(
          deleted: true,
          server: {
            uuid: server.uuid,
            name: server.name
          }
        )
      else
        render_error "DeletionError", message: "The server could not be deleted"
      end
    end
  end
end