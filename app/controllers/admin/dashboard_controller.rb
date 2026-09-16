module Admin
  class DashboardController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin

    def index
      @users = User.all
      @jobs = Job.all
      @dashboard_counts = {
        pending: @jobs.pending.count,
        scheduled: @jobs.scheduled.count,
        in_progress: @jobs.in_progress.count,
        completed: @jobs.completed.count,
        invoiced: @jobs.invoiced.count
      }
      @settings = Setting.first_or_create
    end

    private

    def require_admin
      unless current_user.admin? || current_user.super_admin?
        redirect_to root_path, alert: "You are not authorized to access admin area."
      end
    end
  end
end