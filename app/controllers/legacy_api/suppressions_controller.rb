# frozen_string_literal: true

module LegacyAPI
  class SuppressionsController < BaseController

    # Returns the suppression list with pagination
    #
    #   URL:            /api/v1/suppressions/list
    #
    #   Parameters:     page            => The page number (default: 1)
    #                   per_page        => Number of items per page (default: 30)
    #
    #   Response:       A hash containing suppression list with pagination info
    #
    def list
      page = api_params["page"] || 1
      per_page = api_params["per_page"] || 30

      # Validate pagination parameters
      page = page.to_i
      per_page = per_page.to_i

      # Ensure per_page is within reasonable bounds
      per_page = 30 if per_page <= 0
      per_page = 100 if per_page > 100

      # Get paginated suppressions from the server's message database
      result = @current_credential.server.message_db.suppression_list.all_with_pagination(page, per_page: per_page)

      # Transform the records to match the required format
      suppressions = result[:records].map do |record|
        {
          email: record["address"],
          reason: record["reason"],
          createdAt: record["timestamp"] ? Time.at(record["timestamp"]).iso8601 : nil,
          expireAt: record["keep_until"] ? Time.at(record["keep_until"]).iso8601 : nil
        }
      end

      render_success(
        suppressions: suppressions,
        pagination: {
          page: page,
          per_page: result[:per_page],
          total: result[:total],
          total_pages: result[:total_pages]
        }
      )
    end

  end
end
