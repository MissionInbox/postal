# frozen_string_literal: true

class CheckAllDNSScheduledTask < ApplicationScheduledTask

  def call
    Domain.where.not(dns_checked_at: nil).where("dns_checked_at <= ?", 1.hour.ago).each do |domain|
      begin
        domain.with_lock do
          # Reload to get fresh data after acquiring lock
          domain.reload
          # Skip if another worker already checked it
          next if domain.dns_checked_at && domain.dns_checked_at > 1.hour.ago

          logger.info "checking DNS for domain: #{domain.name}"
          domain.check_dns(:auto)
        end
      rescue ActiveRecord::RecordNotFound
        # Domain was deleted, skip it
        next
      end
    end

    TrackDomain.where("dns_checked_at IS NULL OR dns_checked_at <= ?", 1.hour.ago).includes(:domain).each do |domain|
      begin
        domain.with_lock do
          domain.reload
          next if domain.dns_checked_at && domain.dns_checked_at > 1.hour.ago

          logger.info "checking DNS for track domain: #{domain.full_name}"
          domain.check_dns
        end
      rescue ActiveRecord::RecordNotFound
        next
      end
    end
  end

end
