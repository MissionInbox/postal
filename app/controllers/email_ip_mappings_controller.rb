# frozen_string_literal: true

class EmailIPMappingsController < ApplicationController

  include WithinOrganization
  
  before_action { @server = organization.servers.present.find_by_permalink!(params[:server_id]) }
  before_action { params[:id] && @mapping = @server.email_ip_mappings.find(params[:id]) }
  before_action { @active_nav = :email_ip_mappings }
  
  def index
    @mappings = @server.email_ip_mappings.includes(:ip_address).order(:email_address).to_a
  end
  
  def new
    @mapping = @server.email_ip_mappings.build
  end
  
  def create
    @mapping = @server.email_ip_mappings.build(permitted_params)
    if @mapping.save
      redirect_to organization_server_email_ip_mappings_path(organization, @server), notice: "Mapping created successfully"
    else
      render 'new'
    end
  end
  
  def edit
  end
  
  def update
    if @mapping.update(permitted_params)
      redirect_to organization_server_email_ip_mappings_path(organization, @server), notice: "Mapping updated successfully"
    else
      render 'edit'
    end
  end
  
  def destroy
    @mapping.destroy
    redirect_to organization_server_email_ip_mappings_path(organization, @server), notice: "Mapping deleted successfully"
  end
  
  private
  
  def permitted_params
    params.require(:email_ip_mapping).permit(:email_address, :ip_address_id)
  end

end