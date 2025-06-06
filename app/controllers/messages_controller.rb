# frozen_string_literal: true

class MessagesController < ApplicationController

  include WithinOrganization

  before_action { @server = organization.servers.present.find_by_permalink!(params[:server_id]) }
  before_action { params[:id] && @message = @server.message_db.message(params[:id].to_i) }

  def new
    if params[:direction] == "incoming"
      @message = IncomingMessagePrototype.new(@server, request.ip, "web-ui", {})
      @message.from = session[:test_in_from] || current_user.email_tag
      @message.to = @server.routes.order(:name).first&.description
    else
      @message = OutgoingMessagePrototype.new(@server, request.ip, "web-ui", {})
      @message.to = session[:test_out_to] || current_user.email_address
      if domain = @server.domains.verified.order(:name).first
        @message.from = "test@#{domain.name}"
      end
    end
    @message.subject = "Test Message at #{Time.zone.now.to_fs(:long)}"
    @message.plain_body = "This is a message to test the delivery of messages through Postal."
  end

  def create
    if params[:direction] == "incoming"
      session[:test_in_from] = params[:message][:from] if params[:message]
      @message = IncomingMessagePrototype.new(@server, request.ip, "web-ui", params[:message])
      @message.attachments = [{ name: "test.txt", content_type: "text/plain", data: "Hello world!" }]
    else
      session[:test_out_to] = params[:message][:to] if params[:message]
      @message = OutgoingMessagePrototype.new(@server, request.ip, "web-ui", params[:message])
    end
    if result = @message.create_messages
      if result.size == 1
        redirect_to_with_json organization_server_message_path(organization, @server, result.first.last[:id]), notice: "Message was queued successfully"
      else
        redirect_to_with_json [:queue, organization, @server], notice: "Messages queued successfully "
      end
    else
      respond_to do |wants|
        wants.html do
          flash.now[:alert] = "Your message could not be sent. Ensure that all fields are completed fully. #{result.errors.inspect}"
          render "new"
        end
        wants.json do
          render json: { flash: { alert: "Your message could not be sent. Please check all field are completed fully." } }
        end
      end

    end
  end

  def outgoing
    @searchable = true
    get_messages("outgoing")
    respond_to do |wants|
      wants.html
      wants.json do
        render json: {
          flash: flash.each_with_object({}) { |(type, message), hash| hash[type] = message },
          region_html: render_to_string(partial: "index", formats: [:html])
        }
      end
    end
  end

  def incoming
    @searchable = true
    get_messages("incoming")
    respond_to do |wants|
      wants.html
      wants.json do
        render json: {
          flash: flash.each_with_object({}) { |(type, message), hash| hash[type] = message },
          region_html: render_to_string(partial: "index", formats: [:html])
        }
      end
    end
  end

  def held
    get_messages("held")
  end

  def deliveries
    render json: { html: render_to_string(partial: "deliveries", locals: { message: @message }) }
  end

  def html_raw
    render html: @message.html_body_without_tracking_image.html_safe
  end

  def spam_checks
    @spam_checks = @message.spam_checks.sort_by { |s| s["score"] }.reverse
  end

  def attachment
    if @message.attachments.size > params[:attachment].to_i
      attachment = @message.attachments[params[:attachment].to_i]
      send_data attachment.body, content_type: attachment.mime_type, disposition: "download", filename: attachment.filename
    else
      redirect_to attachments_organization_server_message_path(organization, @server, @message.id), alert: "Attachment not found. Choose an attachment from the list below."
    end
  end

  def download
    if @message.raw_message
      send_data @message.raw_message, filename: "Message-#{organization.permalink}-#{@server.permalink}-#{@message.id}.eml", content_type: "text/plain"
    else
      redirect_to organization_server_message_path(organization, @server, @message.id), alert: "We no longer have the raw message stored for this message."
    end
  end

  def retry
    if @message.raw_message?
      if @message.queued_message
        @message.queued_message.retry_now
        flash[:notice] = "This message will be retried shortly."
      elsif @message.held?
        @message.add_to_message_queue(manual: true)
        flash[:notice] = "This message has been released. Delivery will be attempted shortly."
      else
        @message.add_to_message_queue(manual: true)
        flash[:notice] = "This message will be redelivered shortly."
      end
    else
      flash[:alert] = "This message is no longer available."
    end
    redirect_to_with_json organization_server_message_path(organization, @server, @message.id)
  end

  def cancel_hold
    @message.cancel_hold
    redirect_to_with_json organization_server_message_path(organization, @server, @message.id)
  end

  def remove_from_queue
    if @message.queued_message && !@message.queued_message.locked?
      @message.queued_message.destroy
    end
    redirect_to_with_json organization_server_message_path(organization, @server, @message.id)
  end

  def suppressions
    @query = params[:query]
    if @query.present?
      @suppressions = @server.message_db.suppression_list.search_with_pagination(params[:page], @query)
    else
      @suppressions = @server.message_db.suppression_list.all_with_pagination(params[:page])
    end
  end
  
  def remove_suppression
    type = params[:type]
    address = params[:address]
    if @server.message_db.suppression_list.remove(type, address)
      flash[:notice] = "#{address} has been removed from the suppression list."
    else
      flash[:alert] = "Could not remove #{address} from the suppression list."
    end
    redirect_to suppressions_organization_server_messages_path(organization, @server)
  end
  
  def remove_all_suppressions
    count = @server.message_db.suppression_list.remove_all
    if count > 0
      flash[:notice] = "All #{count} entries have been removed from the suppression list."
    else
      flash[:notice] = "The suppression list was already empty."
    end
    redirect_to suppressions_organization_server_messages_path(organization, @server)
  end
  
  def purge_held_messages
    # Find all held messages
    messages = @server.message_db.messages(where: { held: true })
    count = 0
    
    # Cancel hold for each message and add to queue
    messages.each do |message|
      message.cancel_hold
      message.add_to_message_queue(manual: true)
      count += 1
    end
    
    if count > 0
      flash[:notice] = "#{count} held messages have been canceled and released for delivery."
    else
      flash[:notice] = "No held messages to release and send."
    end
    redirect_to held_organization_server_messages_path(organization, @server)
  end

  def activity
    @entries = @message.activity_entries
  end

  private

  def get_messages(scope)
    if scope == "held"
      options = { where: { held: true } }
    else
      options = { where: { scope: scope, spam: false }, order: :timestamp, direction: "desc" }

      if @query = (params[:query] || session["msg_query_#{@server.id}_#{scope}"]).presence
        session["msg_query_#{@server.id}_#{scope}"] = @query
        qs = QueryString.new(@query)
        if qs.empty?
          flash.now[:alert] = "It doesn't appear you entered anything to filter on. Please double check your query."
        else
          @queried = true
          if qs[:order] == "oldest-first"
            options[:direction] = "asc"
          end

          options[:where][:rcpt_to] = qs[:to] if qs[:to]
          options[:where][:mail_from] = qs[:from] if qs[:from]
          options[:where][:status] = qs[:status] if qs[:status]
          options[:where][:token] = qs[:token] if qs[:token]

          if qs[:msgid]
            options[:where][:message_id] = qs[:msgid]
            options[:where].delete(:spam)
            options[:where].delete(:scope)
          end
          options[:where][:tag] = qs[:tag] if qs[:tag]
          options[:where][:id] = qs[:id] if qs[:id]
          options[:where][:spam] = true if qs[:spam] == "yes" || qs[:spam] == "y"
          if qs[:before] || qs[:after]
            options[:where][:timestamp] = {}
            if qs[:before]
              begin
                options[:where][:timestamp][:less_than] = get_time_from_string(qs[:before]).to_f
              rescue TimeUndetermined
                flash.now[:alert] = "Couldn't determine time for before from '#{qs[:before]}'"
              end
            end

            if qs[:after]
              begin
                options[:where][:timestamp][:greater_than] = get_time_from_string(qs[:after]).to_f
              rescue TimeUndetermined
                flash.now[:alert] = "Couldn't determine time for after from '#{qs[:after]}'"
              end
            end
          end
        end
      else
        session["msg_query_#{@server.id}_#{scope}"] = nil
      end
    end

    @messages = @server.message_db.messages_with_pagination(params[:page], options)
  end

  class TimeUndetermined < Postal::Error; end

  def get_time_from_string(string)
    begin
      if string =~ /\A(\d{2,4})-(\d{2})-(\d{2}) (\d{2}):(\d{2})\z/
        time = Time.new(::Regexp.last_match(1).to_i, ::Regexp.last_match(2).to_i, ::Regexp.last_match(3).to_i, ::Regexp.last_match(4).to_i, ::Regexp.last_match(5).to_i)
      elsif string =~ /\A(\d{2,4})-(\d{2})-(\d{2})\z/
        time = Time.new(::Regexp.last_match(1).to_i, ::Regexp.last_match(2).to_i, ::Regexp.last_match(3).to_i, 0)
      else
        time = Chronic.parse(string, context: :past)
      end
    rescue StandardError
      time = nil
    end

    raise TimeUndetermined, "Couldn't determine a suitable time from '#{string}'" if time.nil?

    time
  end

end
