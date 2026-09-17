class JobsController < ApplicationController
  include Pagy::Method
  before_action :set_job, only: %i[ show edit update destroy schedule whatsapp confirm_whatsapp update_job_type update_assigned_to add_extra_day close update_status ]

  def index
    @jobs = policy_scope(Job).includes(:user, :assigned_to)
    
    # Default to tomorrow's date for scheduled filter if no date provided
    if params[:filter] == "scheduled" && params[:filter_date].blank?
      @filter_date = Date.tomorrow
    else
      @filter_date = params[:filter_date].present? ? Date.parse(params[:filter_date]) : nil
    end

    # Base scope for pipeline
    if current_user.super_admin?
      @pipeline_scope = policy_scope(Job).where(user: current_user)
    elsif current_user.scheduler? || current_user.reporter? || current_user.accountant? || current_user.admin?
      @pipeline_scope = policy_scope(Job)
    else
      @pipeline_scope = policy_scope(Job)
    end

    @pipeline_scope = filter_jobs if params[:filter].present?
    @pipeline_scope = @pipeline_scope.search(params[:q]) if params[:q].present?
    @search_query = params[:q]
    @pipeline_scope = sort_job_list(@pipeline_scope)

    # Default to newest-first by scheduled date for scheduler/super_admin/accountant
    if (current_user.super_admin? || current_user.scheduler? || current_user.accountant?) && params[:sort].blank?
      @pipeline_scope = @pipeline_scope.order(scheduled_date: :desc, scheduled_time: :desc)
    end

    # Paginate the pipeline - 100 per page
    @pagy, @pipeline_jobs = pagy(:offset, @pipeline_scope, limit: 100)

    # For backwards compat with other roles
    @jobs = @pipeline_jobs
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

  def add_extra_day
    authorize @job, :add_extra_day?
    @job.add_extra_day!
    redirect_back(fallback_location: job_path(@job), notice: "Extended the job end date by one day.")
  end

  def update_status
    authorize @job, :update_status?

    requested_status = params[:status]
    @job.status = requested_status == "invoiced" ? :completed : requested_status
    if @job.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("job-#{@job.id}-status", partial: "dashboard/status_dropdown", locals: { job: @job })
        end
        format.html { redirect_back(fallback_location: dashboard_path, notice: "Job status was updated.") }
      end
    else
      redirect_back(fallback_location: dashboard_path, alert: @job.errors.full_messages.join(", "))
    end
  end

  def update_job_type
    authorize @job, :update_job_type?

    @job.is_project = ActiveRecord::Type::Boolean.new.cast(params[:is_project])
    if @job.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("job-#{@job.id}-job-type", partial: "dashboard/job_type_dropdown", locals: { job: @job })
        end
        format.html { redirect_back(fallback_location: dashboard_path, notice: "Job type was updated.") }
      end
    else
      redirect_back(fallback_location: dashboard_path, alert: @job.errors.full_messages.join(", "))
    end
  end

  def update_assigned_to
    authorize @job, :update_assigned_to?

    @job.assigned_to_id = params[:assigned_to_id].present? ? params[:assigned_to_id] : nil
    if @job.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("job-#{@job.id}-assigned-to", partial: "dashboard/assigned_to_dropdown", locals: { job: @job })
        end
        format.html { redirect_back(fallback_location: dashboard_path, notice: "Assigned plumber was updated.") }
      end
    else
      redirect_back(fallback_location: dashboard_path, alert: @job.errors.full_messages.join(", "))
    end
  end

  def close
    authorize @job, :close?

    if @job.completed?
      redirect_back(fallback_location: @job, notice: "Job is already completed.")
      return
    end

    # For accountants, require invoice_number to be set before closing
    if current_user.accountant? && @job.invoice_number.blank?
      redirect_back(fallback_location: @job, alert: "Please assign an invoice number before closing this job.")
      return
    end

    @job.status = :completed
    if @job.save
      redirect_back(fallback_location: @job, notice: "Job was closed and marked as invoiced.")
    else
      redirect_back(fallback_location: @job, alert: @job.errors.full_messages.join(", "))
    end
  end

  def whatsapp
    authorize @job, :show?

    phone = @job.assigned_to&.phone_number
    if phone.present?
      message = "New Job Assigned:\n\nCustomer: #{@job.customer_name}\n\nAddress: #{@job.address}\n\nDescription: #{@job.description}\n\nTomorrow#{@job.scheduled_time&.strftime(' at %I:%M %p')}"
      redirect_to "https://wa.me/#{phone.gsub(/[^0-9]/, '')}?text=#{CGI.escape(message)}", allow_other_host: true
    else
      redirect_to @job, alert: "No phone number available for the assigned plumber."
    end
  end

  def schedule_whatsapp
    authorize @job, :show?

    phone = @job.assigned_to&.phone_number
    if phone.present?
      service_type = @job.project? ? "Project" : "Car Service"
      message = "For Your Attention\n\n#{service_type}\n\nDate: #{@job.scheduled_date&.strftime('%d %B %Y')}\n\nTime: #{@job.scheduled_time&.strftime('%I:%M %p')}\n\nCustomer: #{@job.customer_name}\n\nAddress: #{@job.address}\n\nDescription: #{@job.description}"
      redirect_to "https://wa.me/#{phone.gsub(/[^0-9]/, '')}?text=#{CGI.escape(message)}", allow_other_host: true
    else
      redirect_to dashboard_path, alert: "No phone number available for the assigned plumber."
    end
  end

  def confirm_whatsapp
    authorize @job, :show?
    @job.update(whatsapp_sent_at: Time.current.in_time_zone('Africa/Johannesburg'))

    phone = @job.assigned_to&.phone_number
    if phone.present?
      message = "New Job Assigned:\n\nCustomer: #{@job.customer_name}\n\nAddress: #{@job.address}\n\nDescription: #{@job.description}\n\nTomorrow#{@job.scheduled_time&.strftime(' at %I:%M %p')}"
      whatsapp_url = "https://wa.me/#{phone.gsub(/[^0-9]/, '')}?text=#{CGI.escape(message)}"
      render json: {
        timestamp: (@job.whatsapp_sent_at + 2.hours).strftime('%d %b %Y'),
        time: (@job.whatsapp_sent_at + 2.hours).strftime('%I:%M %p'),
        whatsapp_url: whatsapp_url
      }
    else
      render json: { error: "No phone number available" }, status: :unprocessable_entity
    end
  end

  def bulk_whatsapp
    authorize Job, :schedule?

    date = Date.parse(params[:scheduled_date]) rescue Date.tomorrow
    jobs = policy_scope(Job).scheduled.where(scheduled_date: date)
    @jobs = jobs.select { |job| job.assigned_to&.phone_number.present? }
    @date = date
  end

  def print_tomorrow
    authorize Job, :schedule?
    @print_date = Date.tomorrow
    @jobs = policy_scope(Job).scheduled.where(scheduled_date: @print_date).order(:scheduled_time)
  end

  private

  def set_job
    @job = Job.find(params[:id])
  end

  def job_params
    permitted = if current_user.accountant?
      [ :invoice_number ]
    else
      [ :customer_code, :customer_name, :contact_person, :email, :address, :postal_address, :description, :status, :priority, :assigned_to_id, :notes, :scheduled_date, :scheduled_time, :scheduled_end_date, :job_number, :invoice_number, :is_project, :client_id, :contact_number ]
    end
    params.require(:job).permit(permitted)
  end

  def schedule_params
    params.permit(:status, :scheduled_date, :scheduled_time, :assigned_to_id)
  end

  def filter_jobs(scope = nil)
    scope ||= @pipeline_scope
    case params[:filter]
    when "pending"
      scope.pending
    when "scheduled"
      scoped = scope.scheduled
      scoped = scoped.where(scheduled_date: @filter_date) if @filter_date
      scoped
    when "completed"
      scope.completed
    when "in_progress"
      scope.in_progress
    when "outstanding"
      scope.outstanding
    when "invoiced"
      scope.invoiced
    when "my_jobs"
      scope.where(assigned_to: current_user)
    else
      scope
    end
  end
end
