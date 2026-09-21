class Admin::ReportsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

   def index
    @reports = Report.order(created_at: :desc)
    @search_query = params[:q].to_s.strip
    if @search_query.present?
      sanitized = "%#{ActiveRecord::Base.sanitize_sql_like(@search_query)}%"
      @reports = @reports.where("LOWER(title) LIKE LOWER(:q) OR LOWER(description) LIKE LOWER(:q) OR LOWER(role) LIKE LOWER(:q)", q: sanitized)
    end
    page = (params[:page] || 1).to_i
    page = 1 if page < 1
    @reports = @reports.limit(25).offset((page - 1) * 25)
    @total_pages = (Report.count.to_f / 25).ceil
  end

  def destroy
    @report = Report.find(params[:id])
    @report.destroy
    redirect_to admin_reports_path, notice: "Report was deleted."
  end

  private

  def require_admin
    unless current_user.admin? || current_user.super_admin?
      redirect_to root_path, alert: "You are not authorized to access this section."
    end
  end
end
