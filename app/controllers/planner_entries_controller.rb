class PlannerEntriesController < ApplicationController
  before_action :set_planner_entry, only: %i[ show edit update destroy whatsapp ]

  def index
    @planner_entries = policy_scope(PlannerEntry).includes(:assigned_to, :created_by)
    @planner_entries = @planner_entries.search(params[:q]) if params[:q].present?
    @planner_entries = @planner_entries.order(:entry_date, :entry_time)
  end

  def upcoming
    @planner_entries = policy_scope(PlannerEntry).upcoming.includes(:assigned_to, :created_by)
    @planner_entries = @planner_entries.search(params[:q]) if params[:q].present?
  end

  def past
    @planner_entries = policy_scope(PlannerEntry).past.includes(:assigned_to, :created_by)
    @planner_entries = @planner_entries.search(params[:q]) if params[:q].present?
  end

  def show
  end

  def new
    @planner_entry = PlannerEntry.new
    authorize @planner_entry
  end

  def create
    @planner_entry = PlannerEntry.new(planner_entry_params.merge(created_by: current_user))
    authorize @planner_entry

    if @planner_entry.save
      redirect_to planner_entries_path, notice: "Planner entry was created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @planner_entry
  end

  def update
    if @planner_entry.update(planner_entry_params)
      redirect_to planner_entries_path, notice: "Planner entry was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @planner_entry
    @planner_entry.destroy
    redirect_to planner_entries_path, notice: "Planner entry was deleted."
  end

  def whatsapp
    authorize @planner_entry, :show?

    phone = @planner_entry.assigned_to&.phone_number
    if phone.present?
      category_name = @planner_entry.category.to_s.humanize
      message = "For Your Attention\n\n#{category_name}\n\nDate: #{@planner_entry.entry_date.strftime('%d %B %Y')}\n\nTime: #{@planner_entry.entry_time.strftime('%I:%M %p') if @planner_entry.entry_time}\n\nTitle: #{@planner_entry.title}\n\n#{@planner_entry.description if @planner_entry.description.present?}"
      redirect_to "https://wa.me/#{phone.gsub(/[^0-9]/, '')}?text=#{CGI.escape(message)}", allow_other_host: true
    else
      redirect_to planner_entries_path, alert: "No phone number available for the assigned user."
    end
  end

  private

  def set_planner_entry
    @planner_entry = PlannerEntry.find(params[:id])
  end

  def planner_entry_params
    params.require(:planner_entry).permit(:title, :description, :category, :entry_date, :entry_time, :assigned_to_id, :status, :notes)
  end
end