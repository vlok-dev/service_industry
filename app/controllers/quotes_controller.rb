class QuotesController < ApplicationController
  include Pagy::Method
  before_action :set_quote, only: %i[show edit update destroy print]
  before_action :set_quotes, only: %i[index]
  before_action :set_jobs, only: %i[new create edit update]

  def index
    authorize Quote
    @pagy, @quotes = pagy(@quotes, limit: 100)
  end

  def show
    authorize @quote
  end

  def print
    authorize @quote
    render layout: "quote_print"
  end

  def new
    @quote = current_user.quotes.new
    @quote.items.build
    prefill_from_job
    authorize @quote
  end

  def create
    @quote = current_user.quotes.new(quote_params)
    @quote.created_by = current_user
    authorize @quote

    if @quote.save
      redirect_to quotes_path, notice: "Quote #{@quote.quote_number} was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @quote
    @quote.items.build if @quote.items.empty?
  end

  def update
    authorize @quote
    if @quote.update(quote_params)
      redirect_to quotes_path, notice: "Quote was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @quote
    @quote.destroy
    redirect_to quotes_path, notice: "Quote was deleted."
  end

  private

   def prefill_from_job
    job = Job.find_by(id: params[:job_id])
    return unless job
    @quote.job = job
    @quote.company ||= job.customer_name if job.respond_to?(:customer_name)
    @quote.attention ||= job.contact_person if job.respond_to?(:contact_person)
    @quote.email_address ||= job.email if job.respond_to?(:email)
    @quote.property ||= job.address if job.respond_to?(:address)
    @quote.subject ||= job.description if job.respond_to?(:description)
    @quote.quote_date ||= Date.current
  end

  def set_quote
    @quote = policy_scope(Quote).includes(:job, :created_by, items: :inventory_item).find(params[:id])
  end

  def set_jobs
    @jobs = policy_scope(Job).order(:job_number).limit(100)
  end

  def set_quotes
    @quotes = policy_scope(Quote).includes(:job, :created_by, items: :inventory_item).order(created_at: :desc)
    if params[:q].present?
      query = "%#{params[:q].downcase}%"
      @quotes = @quotes.where(
        "LOWER(quotes.quote_number) LIKE ? OR LOWER(jobs.job_number) LIKE ? OR LOWER(jobs.customer_name) LIKE ?",
        query, query, query
      ).left_joins(:job)
    end
  end

  def quote_params
    params.require(:quote).permit(
      :job_id, :vat_rate, :notes, :terms, :valid_until, :quote_date,
      :company, :attention, :email_address, :property, :subject,
      items_attributes: %i[id code description unit_price inventory_item_id _destroy]
    )
  end
end
