module WhatsappHelper
  # WhatsApp is reached through wa.me deep links, not an API: the link opens
  # WhatsApp with the message pre-filled and a human still presses Send. The
  # app therefore never learns that a message went out - the "are you sure"
  # confirmation is the only signal we get, so every send path funnels through
  # one message builder to keep the text identical everywhere.
  #
  # Phone handling: wa.me needs a bare international number, no "+", spaces or
  # dashes. South African numbers stored locally (082...) get the 27 country
  # code prefixed; numbers already stored internationally are left alone.
  def whatsapp_phone_digits(phone)
    digits = phone.to_s.gsub(/[^0-9]/, "")
    return nil if digits.empty?

    digits = "27#{digits[1..]}" if digits.start_with?("0")
    digits
  end

  def job_whatsapp_recipient(job)
    whatsapp_phone_digits(job.assigned_to&.phone_number)
  end

  def job_whatsapp_message(job)
    # is_project is the "Job Type" column the schedule UI edits. Note that
    # job.project? is NOT this: that is the priority enum's predicate, and
    # reading it here mislabelled maintenance jobs as projects.
    service_type = job.is_project? ? "Project" : "Car Service"

    [
      "For Your Attention",
      "",
      service_type,
      "",
      "Date: #{job.scheduled_date&.strftime('%d %B %Y')}",
      "Time: #{job.scheduled_time&.strftime('%I:%M %p')}",
      "Customer: #{job.customer_name}",
      "Address: #{job.address}",
      "Description: #{job.description}"
    ].join("\n")
  end

  # Returns nil when the assigned plumber has no usable number, so callers can
  # treat "no phone" the same way everywhere instead of building a dead link.
  def job_whatsapp_url(job)
    digits = job_whatsapp_recipient(job)
    return nil if digits.blank?

    "https://wa.me/#{digits}?text=#{CGI.escape(job_whatsapp_message(job))}"
  end

  def job_whatsapp_sendable?(job)
    job.whatsapp_sent_at.nil? && job_whatsapp_url(job).present?
  end

  # whatsapp_sent_at is stored in Africa/Johannesburg but the app runs in UTC,
  # so the stored value is shifted back for display. Kept in one place because
  # every view used to repeat the same +2.hours arithmetic.
  def whatsapp_sent_at_display(job)
    return nil if job.whatsapp_sent_at.blank?

    (job.whatsapp_sent_at + 2.hours).strftime("%d %b %Y at %I:%M %p")
  end
end
