class DashboardController < ApplicationController
  def index
    @jobs = policy_scope(Job)

    case current_user.role
    when "super_admin"
      @my_jobs = @jobs.where(user: current_user)
      @pending_jobs = @jobs.pending
      @in_progress_jobs = @jobs.in_progress
      @completed_jobs = @jobs.completed
      build_schedule_view
      @scheduled_jobs = jobs_for_schedule_view
    when "scheduler"
      @pending_jobs = @jobs.pending
      build_schedule_view
      @scheduled_jobs = jobs_for_schedule_view
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

  private

  def build_schedule_view
    @scheduler_view = params[:view].presence_in(%w[day week month]) || "day"
    @scheduler_date = Date.parse(params[:date]) rescue Date.tomorrow
    @date_range_label = schedule_range_label(@scheduler_view, @scheduler_date)
  end

  def jobs_for_schedule_view
    case @scheduler_view
    when "day"
      @jobs.where(scheduled_date: @scheduler_date)
    when "week"
      week_start = @scheduler_date.beginning_of_week(:monday)
      week_end = @scheduler_date.end_of_week(:monday)
      @jobs.where(scheduled_date: week_start..week_end)
    when "month"
      @jobs.where(scheduled_date: @scheduler_date.beginning_of_month..@scheduler_date.end_of_month)
    end
  end

  def schedule_range_label(view, date)
    case view
    when "day" then date.strftime("%A, %B %d, %Y")
    when "week"
      week_start = date.beginning_of_week(:monday)
      week_end = date.end_of_week(:monday)
      "#{week_start.strftime("%b %d")} \u2014 #{week_end.strftime("%b %d, %Y")}"
    when "month" then date.strftime("%B %Y")
    end
  end
end
