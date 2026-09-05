class SuppliersController < ApplicationController
  before_action :require_manager, except: %i[ index show ]
  before_action :set_supplier, only: %i[ show edit update destroy ]

  def index
    @suppliers = Supplier.ordered
    if params[:q].present?
      term = "%#{Supplier.sanitize_sql_like(params[:q].to_s.strip)}%"
      @suppliers = @suppliers.where(
        "LOWER(name) LIKE LOWER(:q) OR LOWER(contact_person) LIKE LOWER(:q) OR LOWER(phone) LIKE LOWER(:q) OR LOWER(email) LIKE LOWER(:q)",
        q: term
      )
    end
  end

  def show
  end

  def new
    @supplier = Supplier.new
  end

  def create
    @supplier = Supplier.new(supplier_params)
    if @supplier.save
      redirect_to suppliers_path, notice: "Supplier #{@supplier.name} was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @supplier.update(supplier_params)
      redirect_to suppliers_path, notice: "Supplier was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @supplier.destroy
    redirect_to suppliers_path, notice: "Supplier was deleted."
  end

  private

  def require_manager
    return if current_user.admin? || current_user.super_admin?

    redirect_back(fallback_location: root_path, alert: "You are not authorized to manage suppliers.")
  end

  def set_supplier
    @supplier = Supplier.find(params[:id])
  end

  def supplier_params
    params.require(:supplier).permit(:name, :contact_person, :phone, :email, :address)
  end
end
