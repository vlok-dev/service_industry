class PlannerEntryWhatsappReminderJob < ApplicationJob
  queue_as :default

  def perform(planner_entry_id)
    planner_entry = PlannerEntry.find_by(id: planner_entry_id)
    return unless planner_entry&.assigned_to&.phone_number.present?

    send_whatsapp_reminder(planner_entry)
  rescue ActiveRecord::RecordNotFound
    # Entry was deleted, skip
  end

  private

  def send_whatsapp_reminder(entry)
    phone = normalize_phone(entry.assigned_to.phone_number)
    message = build_message(entry)

    # Try Meta Cloud API first, fallback to Twilio, then CallMeBot
    if meta_configured?
      send_via_meta(phone, message)
    elsif twilio_configured?
      send_via_twilio(phone, message)
    elsif callmebot_configured?
      send_via_callmebot(phone, message)
    else
      Rails.logger.warn "No WhatsApp provider configured - reminder not sent"
    end
  end

  def normalize_phone(phone)
    # Clean and convert to international format (SA: 27XXXXXXXXX)
    cleaned = phone.gsub(/[^0-9]/, '')
    cleaned = "27#{cleaned}" unless cleaned.start_with?("27")
    cleaned
  end

  def build_message(entry)
    category = entry.category.to_s.humanize
    date = entry.entry_date.strftime("%d %b %Y")
    time = entry.entry_time&.strftime("%I:%M %p")

    msg = "📋 *Reminder: #{category}*\n\n"
    msg += "*#{entry.title}*\n"
    msg += "📅 #{date}"
    msg += " at #{time}" if time.present?
    msg += "\n#{entry.description}" if entry.description.present?
    msg += "\n\n_Industro Plumbers Planner_"
    msg
  end

  # ===== META CLOUD API (Official, 1000 free/month forever) =====
  def meta_configured?
    Rails.application.credentials.dig(:meta, :access_token).present? &&
    Rails.application.credentials.dig(:meta, :phone_number_id).present?
  end

  def send_via_meta(phone, message)
    access_token = Rails.application.credentials.dig(:meta, :access_token)
    phone_number_id = Rails.application.credentials.dig(:meta, :phone_number_id)

    url = "https://graph.facebook.com/v20.0/#{phone_number_id}/messages"
    headers = {
      "Authorization" => "Bearer #{access_token}",
      "Content-Type" => "application/json"
    }
    body = {
      messaging_product: "whatsapp",
      to: phone,
      type: "text",
      text: { body: message }
    }.to_json

    response = HTTParty.post(url, headers: headers, body: body, timeout: 10)
    if response.success?
      Rails.logger.info "Meta WhatsApp sent to #{phone}: #{response.code}"
    else
      Rails.logger.error "Meta WhatsApp failed: #{response.code} #{response.body}"
      raise "Meta API error" # Trigger fallback
    end
  rescue => e
    Rails.logger.error "Meta WhatsApp exception: #{e.message}"
    raise
  end

  # ===== TWILIO WHATSAPP SANDBOX (Free trial, then paid) =====
  def twilio_configured?
    Rails.application.credentials.dig(:twilio, :account_sid).present? &&
    Rails.application.credentials.dig(:twilio, :auth_token).present? &&
    Rails.application.credentials.dig(:twilio, :from_number).present?
  end

  def send_via_twilio(phone, message)
    account_sid = Rails.application.credentials.dig(:twilio, :account_sid)
    auth_token = Rails.application.credentials.dig(:twilio, :auth_token)
    from_number = Rails.application.credentials.dig(:twilio, :from_number) # e.g., "whatsapp:+14155238886"

    url = "https://api.twilio.com/2010-04-01/Accounts/#{account_sid}/Messages.json"
    auth = { username: account_sid, password: auth_token }
    body = {
      "From" => from_number,
      "To" => "whatsapp:#{phone}",
      "Body" => message
    }

    response = HTTParty.post(url, basic_auth: auth, body: body, timeout: 10)
    if response.success?
      Rails.logger.info "Twilio WhatsApp sent to #{phone}: #{response.code}"
    else
      Rails.logger.error "Twilio WhatsApp failed: #{response.code} #{response.body}"
      raise "Twilio API error"
    end
  rescue => e
    Rails.logger.error "Twilio WhatsApp exception: #{e.message}"
    raise
  end

  # ===== CALLMEBOT (Free, single recipient only) =====
  def callmebot_configured?
    Rails.application.credentials.dig(:callmebot, :api_key).present?
  end

  def send_via_callmebot(phone, message)
    api_key = Rails.application.credentials.dig(:callmebot, :api_key)
    encoded = CGI.escape(message)
    url = "https://api.callmebot.com/whatsapp.php?phone=#{phone}&text=#{encoded}&apikey=#{api_key}"

    response = HTTParty.get(url, timeout: 10)
    if response.code == 200
      Rails.logger.info "CallMeBot WhatsApp sent to #{phone}"
    else
      Rails.logger.error "CallMeBot failed: #{response.code} #{response.body}"
    end
  end
end