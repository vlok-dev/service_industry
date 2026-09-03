class CalendarsController < ApplicationController
  def index
    @view = params[:view] || "month"
    @date = params[:date] ? Date.parse(params[:date]) : Date.today

    case @view
    when "day"
      @jobs = policy_scope(Job).where(scheduled_date: @date)
    when "week"
      start_date = @date.beginning_of_week
      end_date = @date.end_of_week
      @jobs = policy_scope(Job).where(scheduled_date: start_date..end_date)
      @week_start = start_date
    when "month"
      start_date = @date.beginning_of_month.beginning_of_week
      end_date = @date.end_of_month.end_of_week
      @jobs = policy_scope(Job).where(scheduled_date: start_date..end_date)
      @month_start = @date.beginning_of_month
    else
      @view = "month"
      redirect_to calendars_path(view: "month") and return
    end

    @jobs_by_date = @jobs.group_by(&:scheduled_date)
  end

  def previous_date
    date = Date.parse(params[:date])
    new_date = case params[:view]
               when "day" then date - 1.day
               when "week" then date - 1.week
               else date - 1.month
               end
    redirect_to calendars_path(view: params[:view], date: new_date)
  end

  def next_date
    date = Date.parse(params[:date])
    new_date = case params[:view]
               when "day" then date + 1.day
               when "week" then date + 1.week
               else date + 1.month
               end
    redirect_to calendars_path(view: params[:view], date: new_date)
  end
end