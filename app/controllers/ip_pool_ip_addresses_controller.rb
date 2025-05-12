# frozen_string_literal: true

class IPPoolIPAddressesController < ApplicationController

  before_action :admin_required
  before_action { @ip_pool = IPPool.find_by_uuid!(params[:ip_pool_id]) }

  def new
    @ip_addresses = IPAddress.all.reject { |ip| @ip_pool.ip_addresses.include?(ip) }
  end

  def create
    @ip_address = IPAddress.find(params[:ip_address_id])
    
    if @ip_pool.ip_addresses.include?(@ip_address)
      redirect_to_with_json [:edit, @ip_pool], alert: "This IP address is already in this pool."
    else
      @ip_pool.ip_addresses << @ip_address
      redirect_to_with_json [:edit, @ip_pool], notice: "IP address has been added to this pool."
    end
  end

end