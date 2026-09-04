class JobsController < ApplicationController
  before_action :set_job, only: %i[ show edit update destroy schedule whatsapp ]

  def index
    @jobs = policy_scope(Job).includes(:user, :assigned_to)
    @jobs = filter_jobs if params[:filter].present?
    @jobs = @jobs.search(params[:q]) if params[:q].present?
    @search_query = params[:q]
  end

  def show
    authorize @job
  end

  def new
    @job = Job.new
    authorize @job
  end

  def create
    @job = Job.new(job_params.merge(user: current_user))

    if @job.save
      redirect_to jobs_path, notice: "Job was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @job
  end

  def update
    if @job.update(job_params)
      redirect_to @job, notice: "Job was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @job.destroy
    redirect_to jobs_path, notice: "Job was successfully deleted."
  end

  def schedule
    authorize @job, :schedule?

    if @job.update(schedule_params)
      redirect_to jobs_path, notice: "Job was successfully scheduled."
    else
      redirect_back(fallback_location: jobs_path, allow_other_host: false, alert: @job.errors.full_messages.join(", "))
    end
  end

  def whatsapp
    authorize @job, :show?

    phone = @job.assigned_to&.phone_number
    if phone.present?
      message = "New Job Assigned:\nCustomer: #{@job.customer_name}\nAddress: #{@job.address}\nDescription: #{@job.description}\nScheduled: #{@job.scheduled_date&.strftime('%Y-%m-%d')} at #{@job.scheduled_time&.strftime('%H:%M') || 'TBD'}\nPriority: #{@job.priority.humanize}\nStatus: #{@job.status.humanize}"
      redirect_to "https://wa.me/#{phone.gsub(/[^0-9]/, '')}?text=#{CGI.escape(message)}", allow_other_host: true
    else
      redirect_to @job, alert: "No phone number available for the assigned plumber."
    end
  end

  def bulk_whatsapp
    authorize Job, :schedule?

    date = Date.parse(params[:scheduled_date]) rescue Date.tomorrow
    jobs = policy_scope(Job).scheduled.where(scheduled_date: date)
    @jobs = jobs.select { |job| job.assigned_to&.phone_number.present? }
    @date = date
  end

  private

  def set_job
    @job = Job.find(params[:id])
  end

  def job_params
    permitted = if current_user.accountant?
      [:invoice_number]
    else
      [:customer_name, :address, :description, :status, :priority, :assigned_to_id, :notes, :scheduled_date, :scheduled_time, :job_number, :invoice_number]
    end
    params.require(:job).permit(permitted)
  end

  def schedule_params
    params.permit(:status, :scheduled_date, :scheduled_time, :assigned_to_id)
  end

  def filter_jobs
    case params[:filter]
    when "pending"
      policy_scope(Job).pending
    when "scheduled"
      policy_scope(Job).scheduled
    when "completed"
      policy_scope(Job).completed
    when "my_jobs"
      policy_scope(Job).where(assigned_to: current_user)
    else
      policy_scope(Job)
    end
  end
end
