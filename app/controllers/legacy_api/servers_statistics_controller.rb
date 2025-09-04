# frozen_string_literal: true

module LegacyAPI
  class ServersStatisticsController < BaseController
    def email_stats
      # Get parameters
      start_date = api_params["start_date"]
      end_date = api_params["end_date"]
      
      # Validate required parameters
      if start_date.blank?
        render_parameter_error("start_date is required")
        return
      end
      
      if end_date.blank?
        render_parameter_error("end_date is required")
        return
      end
      
      # Parse and validate dates
      begin
        parsed_start_date = Time.parse(start_date).utc
        parsed_end_date = Time.parse(end_date).utc
      rescue ArgumentError
        render_parameter_error("Invalid date format. Use ISO 8601 format (e.g., 2025-01-01T00:00:00Z)")
        return
      end
      
      # Validate date range
      if parsed_start_date >= parsed_end_date
        render_parameter_error("start_date must be before end_date")
        return
      end
      
      # Calculate the date range in days
      days_diff = ((parsed_end_date - parsed_start_date) / 1.day).ceil
      
      # Get current server (from authentication)
      current_server = @current_credential.server
      
      # Calculate statistics for the authenticated server only
      begin
        # Get daily statistics for the date range
        stats_data = current_server.message_db.statistics.get(:daily, [:outgoing], parsed_end_date, days_diff)
        
        # Sum up the sent emails for the date range
        sent_count = 0
        stats_data.each do |date, stats|
          # Only count statistics within our date range
          if date >= parsed_start_date && date <= parsed_end_date
            sent_count += stats[:outgoing] || 0
          end
        end
        
        server_info = {
          uuid: current_server.uuid,
          name: current_server.name,
          permalink: current_server.permalink,
          sent_emails: sent_count
        }
      rescue => e
        # Handle any errors getting statistics
        server_info = {
          uuid: current_server.uuid,
          name: current_server.name,
          permalink: current_server.permalink,
          sent_emails: 0,
          error: "Unable to retrieve statistics"
        }
        sent_count = 0
      end
      
      render_success({
        start_date: parsed_start_date.iso8601,
        end_date: parsed_end_date.iso8601,
        server: server_info
      })
    end
  end
end