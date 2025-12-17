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
    
    def email_stats_breakdown
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

      # Get current server (from authentication)
      current_server = @current_credential.server

      # Query messages grouped by mail_from
      begin
        # Build SQL query to count outgoing messages grouped by mail_from
        sql_query = <<-SQL
          SELECT mail_from, COUNT(*) as count
          FROM `#{current_server.message_db.database_name}`.`messages`
          WHERE scope = 'outgoing'
            AND timestamp >= #{current_server.message_db.escape(parsed_start_date.to_f)}
            AND timestamp <= #{current_server.message_db.escape(parsed_end_date.to_f)}
            AND mail_from IS NOT NULL
            AND mail_from != ''
          GROUP BY mail_from
          ORDER BY count DESC
        SQL

        # Execute query and build breakdown hash
        result = current_server.message_db.query(sql_query)
        breakdown = {}
        result.each do |row|
          breakdown[row["mail_from"]] = row["count"]
        end

        render_success({
          start_date: parsed_start_date.iso8601,
          end_date: parsed_end_date.iso8601,
          breakdown: breakdown,
          total_mailboxes: breakdown.size,
          total_emails: breakdown.values.sum
        })
      rescue => e
        # Handle any errors getting statistics
        render_error "QueryError", message: "Unable to retrieve email statistics breakdown", error: e.message
      end
    end

    def update_mode
      # Get parameters
      mode = api_params["mode"]
      
      # Validate required parameters
      if mode.blank?
        render_parameter_error("mode is required")
        return
      end
      
      # Validate mode value
      unless ["Live", "Development"].include?(mode)
        render_parameter_error("mode must be either 'Live' or 'Development'")
        return
      end
      
      # Get current server (from authentication)
      current_server = @current_credential.server
      
      # Update the server mode
      if current_server.update(mode: mode)
        render_success({
          server: {
            uuid: current_server.uuid,
            name: current_server.name,
            permalink: current_server.permalink,
            mode: current_server.mode,
            updated_at: current_server.updated_at
          }
        })
      else
        render_error "UpdateError", message: "The server mode could not be updated", errors: current_server.errors.full_messages
      end
    end
    
    def delete_server
      # Get current server (from authentication)
      current_server = @current_credential.server
      
      # Soft delete the server (using HasSoftDestroy module)
      if current_server.soft_destroy
        render_success({
          deleted: true,
          server: {
            uuid: current_server.uuid,
            name: current_server.name,
            permalink: current_server.permalink
          }
        })
      else
        render_error "DeletionError", message: "The server could not be deleted"
      end
    end
  end
end