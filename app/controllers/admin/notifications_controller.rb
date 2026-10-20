class Admin::NotificationsController < ApplicationController
  before_action :require_admin

  def index
    @notifications = Notification.order(created_at: :desc)
    @notification = Notification.new
  end

  def destroy
    Notification.find(params[:id]).destroy
    redirect_to admin_notifications_path, notice: "Deleted"
  end

  def create
    @notification = Notification.new(notification_params)
    if @notification.save
      redirect_to admin_notifications_path, notice: "Notification released"
    else
      @notifications = Notification.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  private

  def require_admin
    redirect_to root_path unless current_user&.admin? && !current_user&.super_admin?
  end

  def notification_params
    params.require(:notification).permit(:title, :description, :image_url, :release_date, :show_from)
  end
end

