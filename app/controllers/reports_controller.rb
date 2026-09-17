class ReportsController < ApplicationController
  def new
    @report = current_user.reports.build
  end

  def create
    @report = current_user.reports.build(report_params)
    @report.role = current_user.role
    if @report.save
      redirect_to dashboard_path, notice: "Thank you for your submission!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def report_params
    params.require(:report).permit(:category, :title, :description)
  end
end
