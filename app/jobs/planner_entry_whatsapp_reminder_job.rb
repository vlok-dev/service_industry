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
    phone = entry.assigned_to.phone_number.gsub(/[^0-9]/, '')
    # Ensure SA format: 27XXXXXXXXX
    phone = "27#{phone}" unless phone.start_with?("27")

    message = build_message(entry)
    encoded_message = CGI.escape(message)

    # CallMeBot free API
    # Get API key from: https://www.callmebot.com/blog/free-api-whatsapp-messages/
    api_key = Rails.application.credentials.dig(:callmebot, :api_key) || ENV["CALLMEBOT_API_KEY"]

    if api_key.present?
      url = "https://api.callmebot.com/whatsapp.php?phone=#{phone}&text=#{encoded_message}&apikey=#{api_key}"
      response = HTTParty.get(url, timeout: 10)
      Rails.logger.info "WhatsApp reminder sent to #{phone}: #{response.code}"
    else
      Rails.logger.warn "CallMeBot API key not configured - WhatsApp reminder not sent"
    end
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
end