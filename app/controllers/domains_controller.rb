# frozen_string_literal: true

require 'csv'

class DomainsController < ApplicationController

  include WithinOrganization

  before_action do
    if params[:server_id]
      @server = organization.servers.present.find_by_permalink!(params[:server_id])
      params[:id] && @domain = @server.domains.find_by_uuid!(params[:id])
    else
      params[:id] && @domain = organization.domains.find_by_uuid!(params[:id])
    end
  end

  def index
    @page = (params[:page] || 1).to_i
    @per_page = 30
    @search = params[:search]
    
    if @server
      @domains_scope = @server.domains
    else
      @domains_scope = organization.domains
    end
    
    # Apply search if provided
    if @search.present?
      @domains_scope = @domains_scope.where("name LIKE ?", "%#{@search}%")
    end
    
    # Always sort by name
    @domains_scope = @domains_scope.order(:name)
    
    @total_domains = @domains_scope.count
    @total_pages = (@total_domains.to_f / @per_page).ceil
    @domains = @domains_scope.limit(@per_page).offset((@page - 1) * @per_page).to_a
  end

  def new
    @domain = @server ? @server.domains.build : organization.domains.build
  end

  def create
    scope = @server ? @server.domains : organization.domains
    @domain = scope.build(params.require(:domain).permit(:name, :verification_method))

    if current_user.admin?
      @domain.verification_method = "DNS"
      @domain.verified_at = Time.now
    end

    if @domain.save
      if @domain.verified?
        redirect_to_with_json [:setup, organization, @server, @domain]
      else
        redirect_to_with_json [:verify, organization, @server, @domain]
      end
    else
      render_form_errors "new", @domain
    end
  end

  def destroy
    @domain.destroy
    redirect_to_with_json [organization, @server, :domains]
  end

  def verify
    if @domain.verified?
      redirect_to [organization, @server, :domains], alert: "#{@domain.name} has already been verified."
      return
    end

    return unless request.post?

    case @domain.verification_method
    when "DNS"
      if @domain.verify_with_dns
        redirect_to_with_json [:setup, organization, @server, @domain], notice: "#{@domain.name} has been verified successfully. You now need to configure your DNS records."
      else
        respond_to do |wants|
          wants.html { flash.now[:alert] = "We couldn't verify your domain. Please double check you've added the TXT record correctly." }
          wants.json { render json: { flash: { alert: "We couldn't verify your domain. Please double check you've added the TXT record correctly." } } }
        end
      end
    when "Email"
      if params[:code]
        if @domain.verification_token == params[:code].to_s.strip
          @domain.mark_as_verified
          redirect_to_with_json [:setup, organization, @server, @domain], notice: "#{@domain.name} has been verified successfully. You now need to configure your DNS records."
        else
          respond_to do |wants|
            wants.html { flash.now[:alert] = "Invalid verification code. Please check and try again." }
            wants.json { render json: { flash: { alert: "Invalid verification code. Please check and try again." } } }
          end
        end
      elsif params[:email_address].present?
        raise Postal::Error, "Invalid email address" unless @domain.verification_email_addresses.include?(params[:email_address])

        AppMailer.verify_domain(@domain, params[:email_address], current_user).deliver
        if @domain.owner.is_a?(Server)
          redirect_to_with_json verify_organization_server_domain_path(organization, @server, @domain, email_address: params[:email_address])
        else
          redirect_to_with_json verify_organization_domain_path(organization, @domain, email_address: params[:email_address])
        end
      end
    end
  end

  def setup
    return if @domain.verified?

    redirect_to [:verify, organization, @server, @domain], alert: "You can't set up DNS for this domain until it has been verified."
  end

  def check
    if @domain.check_dns(:manual)
      redirect_to_with_json [organization, @server, :domains], notice: "Your DNS records for #{@domain.name} look good!"
    else
      redirect_to_with_json [:setup, organization, @server, @domain], alert: "There seems to be something wrong with your DNS records. Check below for information."
    end
  end
  
  def verify_all
    if @server
      # Include domains with missing or incomplete DNS verification
      @domains = @server.domains.where("dns_checked_at IS NULL OR dkim_status != 'OK' OR spf_status != 'OK' OR return_path_status != 'OK'").to_a
    else
      @domains = organization.domains.where("dns_checked_at IS NULL OR dkim_status != 'OK' OR spf_status != 'OK' OR return_path_status != 'OK'").to_a
    end
    
    verified_count = 0
    error_count = 0
    
    @domains.each do |domain|
      # Only check domains that are already verified or use DNS verification
      if domain.verified? || domain.verification_method == "DNS"
        begin
          if domain.check_dns(:manual)
            verified_count += 1
          else
            error_count += 1
          end
        rescue => e
          # Log error but continue with other domains
          Rails.logger.error "Error verifying domain #{domain.name}: #{e.message}"
          error_count += 1
        end
      end
    end
    
    if verified_count > 0
      message = "#{verified_count} #{'domain'.pluralize(verified_count)} verified successfully."
      message += " #{error_count} #{'domain'.pluralize(error_count)} failed verification." if error_count > 0
      redirect_to_with_json [organization, @server, :domains], notice: message
    else
      redirect_to_with_json [organization, @server, :domains], alert: "No domains could be verified. Make sure you've added the DNS records correctly."
    end
  end
  
  def export
    # Export all domains without pagination
    if @server
      domains_for_export = @server.domains.order(:name)
    else
      domains_for_export = organization.domains.order(:name)
    end
    
    csv_data = CSV.generate do |csv|
      csv << ["Domain Name", "SPF Status", "DKIM Status", "MX Status", "Return Path Status", "Verified", "SPF Record", "DKIM Record", "Return Path Domain"]
      domains_for_export.each do |domain|
        csv << [
          domain.name,
          domain.spf_status,
          domain.dkim_status,
          domain.mx_status,
          domain.return_path_status,
          domain.verified? ? "Yes" : "No",
          domain.spf_record,
          domain.dkim_record,
          domain.return_path_domain
        ]
      end
    end
    
    send_data csv_data, filename: "domains-#{Time.now.strftime('%Y-%m-%d')}.csv", type: "text/csv"
  end

end
