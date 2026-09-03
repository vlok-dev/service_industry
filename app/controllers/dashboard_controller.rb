class DashboardController < ApplicationController
  def index
    @jobs = policy_scope(Job)

    case current_user.role
    when "super_admin"
      @my_jobs = @jobs.where(user: current_user)
      @pending_jobs = @jobs.pending
      @scheduled_jobs = @jobs.scheduled
      @in_progress_jobs = @jobs.in_progress
      @completed_jobs = @jobs.completed
    when "scheduler"
      @pending_jobs = @jobs.pending

      view = params[:view].presence_in(%w[day week month]) || "day"
      date = Date.parse(params[:date]) rescue Date.tomorrow

      case view
      when "day"
        @scheduled_jobs = @jobs.where(scheduled_date: date)
        @date_range_label = date.strftime("%A, %B %d, %Y")
      when "week"
        week_start = date.beginning_of_week(:monday)
        week_end = date.end_of_week(:monday)
        @scheduled_jobs = @jobs.where(scheduled_date: week_start..week_end)
        @date_range_label = "#{week_start.strftime("%b %d")} — #{week_end.strftime("%b %d, %Y")}"
      when "month"
        month_start = date.beginning_of_month
        month_end = date.end_of_month
        @scheduled_jobs = @jobs.where(scheduled_date: month_start..month_end)
        @date_range_label = date.strftime("%B %Y")
      end

      @scheduler_view = view
      @scheduler_date = date
      @scheduled_tomorrow = @jobs.where(scheduled_date: Date.tomorrow)
    when "reporter"
      @all_jobs = @jobs.order(created_at: :desc)
      @today_jobs = @jobs.where(created_at: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)
    when "plumber"
      @my_jobs = @jobs.where(assigned_to: current_user)
      @pending_jobs = @my_jobs.pending
      @in_progress_jobs = @my_jobs.in_progress
      @completed_jobs = @my_jobs.completed
    end
  end

  helper_method :prev_date, :next_date

  def prev_date
    case @scheduler_view
    when "day" then @scheduler_date - 1.day
    when "week" then @scheduler_date - 1.week
    when "month" then @scheduler_date - 1.month
    else @scheduler_date
    end
  end

  def next_date
    case @scheduler_view
    when "day" then @scheduler_date + 1.day
    when "week" then @scheduler_date + 1.week
    when "month" then @scheduler_date + 1.month
    else @scheduler_date
    end
  end
end