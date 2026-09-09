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
      "Tomorrow at #{job.scheduled_time.strftime('%I:%M %p')}",
    ]
    lines.join("\n\n")
  end
end