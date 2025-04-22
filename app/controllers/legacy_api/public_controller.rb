# frozen_string_literal: true

module LegacyAPI
  # Base controller for public API endpoints that don't require X-Server-API-Key authentication
  class PublicController < ActionController::Base
    skip_before_action :set_browser_id
    skip_before_action :verify_authenticity_token

    before_action :start_timer

    private

    # The Moonrope API spec allows for parameters to be provided in the body
    # along with the application/json content type or they can be provided,
    # as JSON, in the 'params' parameter when used with the
    # application/x-www-form-urlencoded content type. This legacy API needs
    # support both options for maximum compatibility.
    #
    # @return [Hash]
    def api_params
      if request.headers["content-type"] =~ /\Aapplication\/json/
        return params.to_unsafe_hash
      end

      if params["params"].present?
        return JSON.parse(params["params"])
      end

      {}
    end

    # The API returns a length of time to complete a request. We'll start
    # a timer when the request starts and then use this method to calculate
    # the time taken to complete the request.
    #
    # @return [void]
    def start_timer
      @start_time = Time.now.to_f
    end

    # Render a successful response to the client
    #
    # @param [Hash] data
    # @return [void]
    def render_success(data)
      render json: { status: "success",
                     time: (Time.now.to_f - @start_time).round(3),
                     flags: {},
                     data: data }
    end

    # Render an error response to the client
    #
    # @param [String] code
    # @param [Hash] data
    # @return [void]
    def render_error(code, data = {})
      render json: { status: "error",
                     time: (Time.now.to_f - @start_time).round(3),
                     flags: {},
                     data: data.merge(code: code) }
    end

    # Render a parameter error response to the client
    #
    # @param [String] message
    # @return [void]
    def render_parameter_error(message)
      render json: { status: "parameter-error",
                     time: (Time.now.to_f - @start_time).round(3),
                     flags: {},
                     data: { message: message } }
    end
  end
end