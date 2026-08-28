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
      @scheduled_today = @jobs.where(scheduled_date: Date.today)
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
end