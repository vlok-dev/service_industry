class PurchaseOrdersController < ApplicationController
  before_action :set_job
  before_action :set_purchase_order, only: %i[ show edit update destroy ]

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

  private

  def set_job
    @job = Job.find(params[:job_id])
  end

  def set_purchase_order
    @purchase_order = @job.purchase_orders.find(params[:id])
  end

  def purchase_order_params
    params.require(:purchase_order).permit(
      :supplier_name, :supplier_contact, :status, :order_date, :expected_delivery, :notes,
      items_attributes: [:id, :description, :quantity, :unit_price, :_destroy]
    )
  end
end