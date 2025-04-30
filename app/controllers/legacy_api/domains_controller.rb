# frozen_string_literal: true

module LegacyAPI
  class DomainsController < BaseController
    DEFAULT_PER_PAGE = 30
    MAX_PER_PAGE = 100
    # Helper method to get DNS records for a domain
    private def get_dns_records_for_domain(domain)
      records = []
      
      # Verification record - only if domain is not verified
      unless domain.verified?
        records << {
          type: "TXT",
          name: domain.name,
          value: domain.dns_verification_string,
          purpose: "verification"
        }
      end
      
      # SPF record
      records << {
        type: "TXT", 
        name: domain.name,
        value: domain.spf_record,
        purpose: "spf"
      }
      
      # DKIM record
      if domain.dkim_record.present? && domain.dkim_record_name.present?
        records << {
          type: "TXT",
          name: domain.dkim_record_name,
          short_name: "#{domain.dkim_identifier}._domainkey",
          value: domain.dkim_record,
          purpose: "dkim"
        }
      end
      
      # Return path record
      records << {
        type: "CNAME",
        name: domain.return_path_domain,
        short_name: Postal::Config.dns.custom_return_path_prefix,
        value: Postal::Config.dns.return_path,
        purpose: "return_path"
      }
      
      # MX records - only for incoming domains
      if domain.incoming?
        records << {
          type: "MX",
          name: domain.name,
          priority: 10,
          value: Postal::Config.dns.mx_records.first,
          purpose: "mx"
        }
      end
      
      # Track domain records if any exist
      if domain.track_domains.exists?
        domain.track_domains.each do |track_domain|
          records << {
            type: "CNAME",
            name: track_domain.name,
            value: Postal::Config.dns.track_domain,
            purpose: "tracking"
          }
        end
      end
      
      records
    end
    
    def list
      # Get pagination parameters from API params
      page = (api_params["page"] || 1).to_i
      per_page = (api_params["per_page"] || DEFAULT_PER_PAGE).to_i
      
      # Limit per_page to prevent excessive queries
      per_page = [per_page, MAX_PER_PAGE].min
      
      # Apply filters if provided
      domains_scope = @current_credential.server.domains
      
      # Filter by verified status if specified
      if api_params.key?("verified")
        verified = api_params["verified"].to_s.downcase == "true"
        domains_scope = verified ? domains_scope.where.not(verified_at: nil) : domains_scope.where(verified_at: nil)
      end
      
      # Filter by name if search term is provided
      if api_params["search"].present?
        search_term = "%#{api_params["search"]}%"
        domains_scope = domains_scope.where("name LIKE ?", search_term)
      end
      
      # Get total count before pagination
      total_count = domains_scope.count
      
      # Apply ordering - default to newest first
      order_by = api_params["order_by"] || "created_at"
      order_dir = (api_params["order_direction"] || "desc").upcase == "ASC" ? "ASC" : "DESC"
      
      # Only allow ordering by valid columns
      valid_columns = %w[name created_at verified_at]
      order_by = "created_at" unless valid_columns.include?(order_by)
      
      domains_scope = domains_scope.order("#{order_by} #{order_dir}")
      
      # Apply pagination
      domains = domains_scope.limit(per_page).offset((page - 1) * per_page)
      
      # Calculate pagination details
      total_pages = (total_count.to_f / per_page).ceil
      
      # Format domain data
      domain_data = domains.map do |domain|
        {
          uuid: domain.uuid,
          name: domain.name,
          verified: domain.verified?,
          verified_at: domain.verified_at,
          verification_method: domain.verification_method,
          dns_checked_at: domain.dns_checked_at,
          created_at: domain.created_at,
          updated_at: domain.updated_at,
          outgoing: domain.outgoing,
          incoming: domain.incoming
        }
      end
      
      # Render paginated response
      render_success(
        domains: domain_data,
        pagination: {
          current_page: page,
          per_page: per_page,
          total_pages: total_pages,
          total_count: total_count
        }
      )
    end
    
    def delete
      # Extract required parameters from URL parameters and api_params as fallback
      domain_name = params[:name] || api_params["name"]
      
      # Validate parameters
      if domain_name.blank?
        render_parameter_error("name is required as a URL parameter or in the request body")
        return
      end
      
      # URL-decode the domain name if needed
      domain_name = URI.decode_www_form_component(domain_name) rescue domain_name
      
      # Log information to help debug (remove in production)
      Rails.logger.info "Searching for domain: '#{domain_name}' in server: #{@current_credential.server.name}"
      Rails.logger.info "Available domains: #{@current_credential.server.domains.pluck(:name).join(', ')}"
      
      # Find the domain - case-insensitive search
      domain = @current_credential.server.domains.where("LOWER(name) = LOWER(?)", domain_name).first
      if domain.nil?
        render_error "InvalidDomain", message: "The domain could not be found with the provided name", name: domain_name
        return
      end
      
      # Delete the domain
      if domain.destroy
        render_success(
          deleted: true,
          domain: {
            uuid: domain.uuid,
            name: domain.name
          }
        )
      else
        render_error "DeletionError", message: "The domain could not be deleted"
      end
    end
    
    def create
      # Extract required parameters
      domain_name = api_params["name"]
      
      # Validate parameters
      if domain_name.blank?
        render_parameter_error("name is required")
        return
      end
      
      # Use the server directly from the credential
      server = @current_credential.server
      
      # Create the domain
      domain = server.domains.build(
        name: domain_name,
        verification_method: "DNS"
      )
      
      domain.verified_at = Time.now

      # Check if domain already exists
      existing_domain = server.domains.find_by(name: domain_name)
      
      if existing_domain
        # Get DNS records for the existing domain
        records = get_dns_records_for_domain(existing_domain)
        
        render_success(
          domain: {
            uuid: existing_domain.uuid,
            name: existing_domain.name,
            verification_method: existing_domain.verification_method,
            verified: existing_domain.verified?,
            verification_token: existing_domain.verification_token,
            dns_verification_string: existing_domain.dns_verification_string,
            created_at: existing_domain.created_at,
            updated_at: existing_domain.updated_at
          },
          dns_records: records
        )
      elsif domain.save
        # Get DNS records for the domain
        records = get_dns_records_for_domain(domain)
        
        render_success(
          domain: {
            uuid: domain.uuid,
            name: domain.name,
            verification_method: domain.verification_method,
            verified: domain.verified?,
            verification_token: domain.verification_token,
            dns_verification_string: domain.dns_verification_string,
            created_at: domain.created_at,
            updated_at: domain.updated_at
          },
          dns_records: records
        )
      else
        render_error "ValidationError", 
                     message: "The domain could not be created",
                     errors: domain.errors.full_messages
      end
    end
    
    def verify
      # Extract required parameters
      domain_name = api_params["name"]
      
      # Validate parameters
      if domain_name.blank?
        render_parameter_error("name is required")
        return
      end
      
      # Find the domain

      domain = @current_credential.server.domains.find_by(name: domain_name)
      if domain.nil?
        render_error "InvalidDomain", message: "The domain could not be found with the provided domain_id"
        return
      end
      
      # Check if domain is already verified
      if domain.verified?
        render_success(
          domain: {
            uuid: domain.uuid,
            name: domain.name,
            verified: domain.verified?,
            verified_at: domain.verified_at
          }
        )
        return
      end
      
      # Verify the domain
      if domain.verification_method == "DNS" && domain.verify_with_dns
        render_success(
          domain: {
            uuid: domain.uuid,
            name: domain.name,
            verified: domain.verified?,
            verified_at: domain.verified_at
          }
        )
      else
        render_error "VerificationFailed",
                     message: "We couldn't verify your domain. Please double check you've added the TXT record correctly.",
                     dns_verification_string: domain.dns_verification_string
      end
    end
    
    def dns_records
      # Extract required parameters
      domain_uuid = api_params["domain_id"]
      domain_name = api_params["domain_name"]
      
      # Validate parameters - require either domain_id or domain_name
      if domain_uuid.blank? && domain_name.blank?
        render_parameter_error("Either domain_id or domain_name is required")
        return
      end
      
      # Find the domain by UUID or name
      domain = if domain_uuid.present?
                 @current_credential.server.domains.find_by_uuid(domain_uuid)
               else
                 @current_credential.server.domains.find_by(name: domain_name)
               end
               
      if domain.nil?
        error_message = domain_uuid.present? ? 
          "The domain could not be found with the provided domain_id" : 
          "The domain could not be found with the provided domain_name"
        render_error "InvalidDomain", message: error_message
        return
      end
      
      # Get DNS records for the domain using the helper method
      records = get_dns_records_for_domain(domain)
      
      render_success(
        domain: {
          uuid: domain.uuid,
          name: domain.name,
          verified: domain.verified?
        },
        dns_records: records
      )
    end
  end
end