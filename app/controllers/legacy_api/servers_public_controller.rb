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
        
        # Check if server already has an SMTP credential
        smtp_credential = existing_server.credentials.where(type: "SMTP").first
        
        # If no SMTP credential exists, create one
        if smtp_credential.nil?
          smtp_credential = existing_server.credentials.create(
            type: "SMTP",
            name: "Default SMTP Credential"
          )
        end
        
        # Build response data for existing server
        response_data = {
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
          smtp_key: smtp_credential.key,
          already_exists: true
        }
        
        # Add IP pool information if one is assigned
        if existing_server.ip_pool
          response_data[:ip_pool] = {
            id: existing_server.ip_pool.id,
            uuid: existing_server.ip_pool.uuid,
            name: existing_server.ip_pool.name,
            auto_assigned: false
          }
        end
        
        # Return the existing server details with API key
        render_success(server: response_data)
        return
      end
      
      # Determine IP pool to use
      ip_pool_id = nil
      
      # Use the provided IP pool ID if specified
      if api_params["ip_pool_id"].present?
        ip_pool_id = api_params["ip_pool_id"]
      # Otherwise, try to find the least used IP pool (auto_assign_ip_pool defaults to true)
      elsif api_params["auto_assign_ip_pool"] != false && api_params["auto_assign_ip_pool"].to_s.downcase != 'false'
        # Only consider pools with at least one IP address
        valid_pools = organization.ip_pools.select { |pool| pool.ip_addresses.any? }
        
        if valid_pools.any?
          # Sort pools by usage (least to most)
          sorted_pools = valid_pools.sort_by do |pool|
            ip_address_ids = pool.ip_addresses.pluck(:id)
            if ip_address_ids.empty?
              Float::INFINITY
            else
              # Count messages for this pool
              count = QueuedMessage.where(ip_address_id: ip_address_ids).count
              ip_count = pool.ip_addresses.count
              ip_count > 0 ? count.to_f / ip_count : Float::INFINITY
            end
          end
          
          # Get top N least used pools (default to top 3)
          top_n_limit = api_params["top_pools_limit"].to_i
          top_n_limit = 5 if top_n_limit <= 0  # Default to 3 if not specified or invalid
          top_n = [sorted_pools.size, top_n_limit].min
          
          # Use a timestamp-based index to rotate through the top pools
          # Changes approximately every minute, ensuring different servers created 
          # within the same minute get different pools
          pool_index = (Time.now.to_i / 60) % top_n
          selected_pool = sorted_pools[pool_index]
          
          ip_pool_id = selected_pool&.id
        end
      end
      
      # Create the server
      server = organization.servers.build(
        name: name,
        mode: api_params["mode"] || "Live",
        ip_pool_id: ip_pool_id,
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
        
        # Create a default SMTP credential for the server
        smtp_credential = server.credentials.create(
          type: "SMTP",
          name: "Default SMTP Credential"
        )
        
        # Build response with IP pool info if applicable
        response_data = {
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
          smtp_key: smtp_credential.key,
          already_exists: false
        }
        
        # Add IP pool information if one was assigned
        if server.ip_pool
          response_data[:ip_pool] = {
            id: server.ip_pool.id,
            uuid: server.ip_pool.uuid,
            name: server.ip_pool.name,
            auto_assigned: api_params["ip_pool_id"].blank? && api_params["auto_assign_ip_pool"] != false && api_params["auto_assign_ip_pool"].to_s.downcase != 'false'
          }
        end
        
        # Return the new server details along with the API key
        render_success(server: response_data)
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