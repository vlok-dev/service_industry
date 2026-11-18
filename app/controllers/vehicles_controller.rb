class VehiclesController < ApplicationController
  before_action :require_fleet_access!
  before_action :set_vehicle, only: %i[show edit update destroy]

  def index
    @vehicles = Vehicle.ordered.includes(:vehicle_tools)
    @q = params[:q].to_s.strip
    if @q.present?
      term = "%#{ActiveRecord::Base.sanitize_sql_like(@q)}%"
      @vehicles = @vehicles.where(
        "LOWER(name) LIKE LOWER(:q) OR LOWER(registration_number) LIKE LOWER(:q) OR LOWER(plumber_name) LIKE LOWER(:q) OR LOWER(assistant_name) LIKE LOWER(:q)",
        q: term
      )
    end
  end

  def show
  end

  def new
    @vehicle = Vehicle.new
    @vehicle.vehicle_tools.build
  end

  def create
    @vehicle = Vehicle.new(vehicle_params)
    if @vehicle.save
      redirect_to vehicles_path, notice: "Vehicle was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @vehicle.vehicle_tools.build if @vehicle.vehicle_tools.empty?
  end

  def update
    if @vehicle.update(vehicle_params)
      redirect_to vehicles_path, notice: "Vehicle was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @vehicle.destroy
    redirect_to vehicles_path, notice: "Vehicle was deleted."
  end

  private

  def require_fleet_access!
    return if current_user.reporter? && current_user.email.to_s.casecmp("leeanne@industroplumbers.co.za").zero?

    redirect_to root_path, alert: "You are not authorized to access this page."
  end

  def set_vehicle
    @vehicle = Vehicle.find(params[:id])
  end

  def vehicle_params
    params.require(:vehicle).permit(
      :name, :registration_number, :plumber_name, :assistant_name,
      :current_mileage, :last_service_date, :next_service_due_date,
      :last_service_notes, :registration_expiry,
      vehicle_tools_attributes: %i[id name quantity signed_off signed_by signed_on notes _destroy]
    )
  end
end
