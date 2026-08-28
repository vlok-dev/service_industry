module Admin
  class SettingsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin
    before_action :set_setting, only: [:edit, :update]

    def index
      @setting = Setting.first_or_create
    end

    def edit
    end

    def update
      if @setting.update(setting_params)
        redirect_to admin_root_path, notice: "Settings were successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_setting
      @setting = Setting.first_or_create
    end

    def setting_params
      params.require(:setting).permit(:company_name, :whatsapp_api_key, :whatsapp_phone_id, :default_job_priority, :working_hours_start, :working_hours_end, :notification_email)
    end

    def require_admin
      unless current_user.admin? || current_user.super_admin?
        redirect_to root_path, alert: "You are not authorized to access admin area."
      end
    end
  end
end