# frozen_string_literal: true

# == Schema Information
#
# Table name: queued_messages
#
#  id            :integer          not null, primary key
#  attempts      :integer          default(0)
#  batch_key     :string(255)
#  domain        :string(255)
#  locked_at     :datetime
#  locked_by     :string(255)
#  manual        :boolean          default(FALSE)
#  priority      :integer          default(0)
#  retry_after   :datetime
#  created_at    :datetime
#  updated_at    :datetime
#  ip_address_id :integer
#  message_id    :integer
#  route_id      :integer
#  server_id     :integer
#
# Indexes
#
#  index_queued_messages_on_domain      (domain)
#  index_queued_messages_on_message_id  (message_id)
#  index_queued_messages_on_priority    (priority)
#  index_queued_messages_on_server_id   (server_id)
#

class QueuedMessage < ApplicationRecord

  include HasMessage
  include HasLocking

  belongs_to :server
  belongs_to :ip_address, optional: true

  before_create :allocate_ip_address

  scope :ready_with_delayed_retry, -> { where("retry_after IS NULL OR retry_after < ?", 30.seconds.ago) }
  scope :with_stale_lock, -> { where("locked_at IS NOT NULL AND locked_at < ?", Postal::Config.postal.queued_message_lock_stale_days.days.ago) }
  scope :order_by_priority, -> { order(priority: :desc, created_at: :asc) }

  def retry_now
    update!(retry_after: nil)
  end

  def send_bounce
    return unless message.send_bounces?

    BounceMessage.new(server, message).queue
  end

  def allocate_ip_address
    return unless Postal.ip_pools?
    return if message.nil?
    
    # Check for email-to-IP mapping first
    if message.mail_from && server
      mapping = EmailIPMapping.match_for_email(server, message.mail_from)
      if mapping&.ip_address
        self.ip_address = mapping.ip_address
        return
      end
    end
    
    # Regular IP pool selection if no mapping found
    pool = server.ip_pool_for_message(message)
    return if pool.nil?

    self.ip_address = pool.ip_addresses.select_by_priority
  end

  def batchable_messages(limit = 10)
    unless locked?
      raise Postal::Error, "Must lock current message before locking any friends"
    end

    if batch_key.nil?
      []
    else
      time = Time.now
      locker = Postal.locker_name
      messages = self.class.ready
                     .where(batch_key: batch_key, ip_address_id: ip_address_id, locked_by: nil, locked_at: nil)
                     .limit(limit)
                     .lock("FOR UPDATE SKIP LOCKED")
                     .to_a

      messages.each do |msg|
        msg.update_columns(locked_by: locker, locked_at: time)
      end

      messages.reject { |msg| msg.id == id }
    end
  end

end
