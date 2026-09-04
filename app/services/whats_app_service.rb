class WhatsAppService
  require "net/http"
  require "uri"
  require "json"

  def self.send_job_details(phone_number, job)
    message = build_message(job)
    send_message(phone_number, message)
  end

  def self.build_message(job)
    lines = [
      "New Job Assigned:",
      "Customer: #{job.customer_name}",
      "Address: #{job.address}",
      "Description: #{job.description}",
      "Scheduled: #{job.scheduled_date&.strftime("%d %B %Y")} at #{job.scheduled_time&.strftime("%I:%M %p") || "TBD"}",
      "Priority: #{job.priority.humanize}",
      "Status: #{job.status.humanize}"
    ]
    lines.join("\n")
  end

  def self.send_message(phone_number, message)
    # This is a placeholder implementation.
    # For production, integrate with a WhatsApp Business API provider like:
    # - Twilio WhatsApp API
    # - Meta WhatsApp Cloud API
    # - MessageBird
    # - Custom WhatsApp Web automation (not recommended for production)

    api_key = Rails.application.credentials.dig(:whatsapp, :api_key)
    phone_id = Rails.application.credentials.dig(:whatsapp, :phone_id)

    return unless api_key && phone_id

    uri = URI.parse("https://graph.facebook.com/v18.0/#{phone_id}/messages")
    headers = {
      "Authorization" => "Bearer #{api_key}",
      "Content-Type" => "application/json"
    }

    body = {
      "messaging_product" => "whatsapp",
      "to" => phone_number,
      "type" => "text",
      "text" => { "body" => message }
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.request_uri, headers)
    request.body = body.to_json
    response = http.request(request)

    response.is_a?(Net::HTTPSuccess)
  rescue => e
    Rails.logger.error "WhatsApp send failed: #{e.message}"
    false
  end
end