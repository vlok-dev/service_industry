class PurchaseOrdersController < ApplicationController
  include Pagy::Method
  before_action :set_job, only: [:new, :create, :show, :edit, :update, :destroy]
  before_action :set_purchase_order, only: [:show, :edit, :update, :destroy]
  before_action :set_purchase_orders, only: [:index]

  def index
    @pagy, @purchase_orders = pagy(@purchase_orders, limit: 100)
  end

  def show
  end

  def new
    @purchase_order = @job.purchase_orders.new
    @purchase_order.items.build
  end

  def create
    @purchase_order = @job.purchase_orders.new(purchase_order_params)
    @purchase_order.created_by = current_user

    if @purchase_order.save
      redirect_to job_purchase_order_path(@job, @purchase_order), notice: "Purchase Order #{@purchase_order.po_number} was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def quick_create
    @purchase_order = @job.purchase_orders.new(
      supplier_name: params[:supplier_name],
      order_date: params[:order_date],
      created_by: current_user
    )

    if params[:description].present? && params[:quantity].present? && params[:unit_price].present?
      @purchase_order.items.build(
        description: params[:description],
        quantity: params[:quantity].to_i,
        unit_price: params[:unit_price].to_f
      )
    end

    if @purchase_order.save
      redirect_back(fallback_location: dashboard_path, notice: "Quick PO #{@purchase_order.po_number} created.")
    else
      redirect_back(fallback_location: dashboard_path, alert: @purchase_order.errors.full_messages.join(", "))
    end
  end

  def edit
  end

  def update
    if @purchase_order.update(purchase_order_params)
      redirect_to job_purchase_order_path(@job, @purchase_order), notice: "Purchase Order was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @purchase_order.destroy
    redirect_to @job, notice: "Purchase Order was deleted."
  end

  def export
    @purchase_orders = @purchase_orders.limit(10000)
    respond_to do |format|
      format.csv do
        send_data generate_csv, filename: "purchase-orders-#{Date.today}.csv"
      end
    end
  end

  private

  def set_job
    @job = Job.find(params[:job_id])
  end

  def set_purchase_order
    @purchase_order = @job.purchase_orders.find(params[:id])
  end

  def set_purchase_orders
    @purchase_orders = PurchaseOrder.includes(:job, :created_by).order(created_at: :desc)
    @purchase_orders = @purchase_orders.joins(:job).where("jobs.id IS NOT NULL")
    if params[:q].present?
      query = "%#{params[:q].downcase}%"
      @purchase_orders = @purchase_orders.where(
        "LOWER(purchase_orders.po_number) LIKE ? OR LOWER(purchase_orders.supplier_name) LIKE ? OR LOWER(jobs.job_number) LIKE ? OR LOWER(jobs.customer_name) LIKE ?",
        query, query, query, query
      )
    end
  end

  def purchase_order_params
    params.require(:purchase_order).permit(
      :supplier_id, :supplier_name, :supplier_contact, :order_date, :expected_delivery, :notes, :vat_rate,
      items_attributes: [ :id, :description, :quantity, :unit_price, :code, :inventory_item_id, :_destroy ]
    )
  end

  def generate_csv
    require 'csv'
    CSV.generate(headers: true) do |csv|
      csv << ["PO #", "Job #", "Customer", "Supplier", "Order Date", "Items", "Total (incl. VAT)", "Created By", "Created At"]
      @purchase_orders.each do |po|
        csv << [
          po.po_number,
          po.job.job_number,
          po.job.customer_name,
          po.supplier_display_name,
          po.order_date&.strftime("%d %b %Y"),
          po.items.count,
          po.total_amount || po.total_including_vat,
          po.created_by&.name,
          po.created_at&.strftime("%d %b %Y %H:%M")
        ]
      end
    end
  end
end
