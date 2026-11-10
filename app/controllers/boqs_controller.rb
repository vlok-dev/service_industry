class BoqsController < ApplicationController
  before_action :set_boq, only: %i[show edit update destroy download]
  before_action :set_jobs, only: %i[new create edit update]

  def index
    authorize Boq
    @boqs = policy_scope(Boq).includes(:job, :created_by).order(created_at: :desc)
  end

  def show
    authorize @boq
  end

  def new
    @boq = Boq.new(project_title: params[:project_title], sheet_name: params[:sheet_name])
    @boq.claim_1_label = "1st claim"
    @boq.claim_2_label = "2nd claim"
    @boq.claim_3_label = "3rd claim"
    @boq.claim_4_label = "4th claim"
    @boq.items.build
    authorize @boq
  end

  def create
    @boq = Boq.new(boq_params)
    @boq.created_by = current_user
    authorize @boq

    if @boq.save
      redirect_to boqs_path, notice: "BoQ #{@boq.boq_number} was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @boq
    @boq.items.build if @boq.items.empty?
  end

  def update
    authorize @boq
    if @boq.update(boq_params)
      redirect_to boqs_path, notice: "BoQ #{@boq.boq_number} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @boq
    @boq.destroy
    redirect_to boqs_path, notice: "BoQ was deleted."
  end

  def download
    authorize @boq, :download?
    send_data(
      @boq.workbook_blob,
      filename: @boq.download_filename,
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
    )
  end

  private

  def set_boq
    @boq = policy_scope(Boq).find(params[:id])
  end

  def set_jobs
    @jobs = policy_scope(Job).order(created_at: :desc).limit(200)
  end

  def boq_params
    params.require(:boq).permit(
      :project_title, :sheet_name, :job_id,
      :claim_1_label, :claim_1_amount,
      :claim_2_label, :claim_2_amount,
      :claim_3_label, :claim_3_amount,
      :claim_4_label,
      items_attributes: %i[id row_type description unit page item_code bill_qty claimed_qty rate total_formula position _destroy]
    )
  end
end
