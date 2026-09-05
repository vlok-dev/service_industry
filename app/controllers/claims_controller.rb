class ClaimsController < ApplicationController
  before_action :set_job
  before_action :require_project
  before_action :require_claim_viewer, only: %i[ index show ]
  before_action :require_claim_editor, only: %i[ new create edit update destroy ]
  before_action :set_claim, only: %i[ show edit update destroy ]

  def index
    @claims = @job.claims.order(claim_date: :desc)
  end

  def show
  end

  def new
    @claim = @job.claims.new
  end

  def create
    @claim = @job.claims.new(claim_params)
    if @claim.save
      redirect_to job_claims_path(@job), notice: "Claim #{@claim.id} was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @claim.update(claim_params)
      redirect_to job_claim_path(@job, @claim), notice: "Claim was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @claim.destroy
    redirect_to job_claims_path(@job), notice: "Claim was deleted."
  end

  private

  def set_job
    @job = Job.find(params[:job_id])
  end

  def require_project
    return if @job.is_project?

    redirect_back(fallback_location: job_path(@job), alert: "Claims can only be added to projects.")
  end

  def require_claim_viewer
    return if current_user.admin? || current_user.super_admin? || current_user.accountant?

    redirect_back(fallback_location: root_path, alert: "You are not authorized to view claims.")
  end

  def require_claim_editor
    return if current_user.admin? || current_user.super_admin? || current_user.accountant? || current_user.scheduler?

    redirect_back(fallback_location: root_path, alert: "You are not authorized to manage claims.")
  end

  def set_claim
    @claim = @job.claims.find(params[:id])
  end

  def claim_params
    params.require(:claim).permit(:amount, :claim_date, :status, :reference, :description)
  end
end
