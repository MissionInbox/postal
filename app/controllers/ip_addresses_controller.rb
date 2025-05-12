# frozen_string_literal: true

class IPAddressesController < ApplicationController

  before_action :admin_required
  before_action { @ip_pool = IPPool.find_by_uuid!(params[:ip_pool_id]) }
  before_action { params[:id] && @ip_address = IPAddress.find(params[:id]) }

  def new
    @ip_address = IPAddress.new
  end

  def create
    @ip_address = IPAddress.new(safe_params)
    ActiveRecord::Base.transaction do
      if @ip_address.save
        @ip_pool.ip_addresses << @ip_address
        redirect_to_with_json [:edit, @ip_pool]
      else
        render_form_errors "new", @ip_address
      end
    end
  end

  def update
    if @ip_address.update(safe_params)
      redirect_to_with_json [:edit, @ip_pool]
    else
      render_form_errors "edit", @ip_address
    end
  end

  def destroy
    if @ip_address.ip_pools.count > 1
      # If IP is in multiple pools, just remove it from this pool
      @ip_pool.ip_addresses.delete(@ip_address)
      redirect_to_with_json [:edit, @ip_pool]
    else
      # If this is the only pool, destroy the IP address entirely
      @ip_address.destroy
      redirect_to_with_json [:edit, @ip_pool]
    end
  end

  private

  def safe_params
    params.require(:ip_address).permit(:ipv4, :ipv6, :hostname, :priority)
  end

end
