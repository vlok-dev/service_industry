class ApplicationController < ActionController::Base
  MOBILE_OR_TABLET_USER_AGENT = /
    Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini|Mobile|Tablet
  /ix

  include Pundit::Authorization
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :force_desktop_on_mobile
  before_action :authenticate_user!
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :track_last_login, if: :user_signed_in?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :role, :phone_number])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :role, :phone_number])
  end

  helper_method :sort_job_list, :force_desktop_layout?

  SORTABLE_JOB_COLUMNS = {
    "job_number" => "jobs.job_number",
    "customer_name" => "jobs.customer_name",
    "address" => "jobs.address",
    "status" => "jobs.status",
    "priority" => "jobs.priority",
    "scheduled_date" => "jobs.scheduled_date",
    "scheduled_time" => "jobs.scheduled_time",
    "invoice_number" => "jobs.invoice_number",
    "created_at" => "jobs.created_at",
    "description" => "jobs.description",
    "is_project" => "jobs.is_project",
    "assigned_to" => "users.name",
    "created_by" => "users.name"
  }.freeze

  private

  def sort_job_list(scope)
    return scope unless params[:sort].present? && SORTABLE_JOB_COLUMNS.key?(params[:sort])

    direction = %w[asc desc].include?(params[:direction]) ? params[:direction].upcase : "ASC"
    column = SORTABLE_JOB_COLUMNS[params[:sort]]

    case params[:sort]
    when "assigned_to"
      scope.left_joins(:assigned_to).order(Arel.sql("COALESCE(users.name, '') #{direction}"))
    when "created_by"
      scope.left_joins(:user).order(Arel.sql("COALESCE(users.name, '') #{direction}"))
    else
      scope.order(Arel.sql("#{column} #{direction}"))
    end
  end

  def force_desktop_on_mobile
    return unless request.format.html?

    vary_headers = ["User-Agent", "Sec-CH-UA-Mobile", "Sec-CH-UA-Platform"]
    existing_vary = response.get_header("Vary").to_s.split(",").map(&:strip).reject(&:empty?)
    response.set_header("Vary", (existing_vary + vary_headers).uniq.join(", "))
    request.variant = :desktop if mobile_or_tablet_request?
  end

  def force_desktop_layout?
    request.variant.desktop?
  end

  def mobile_or_tablet_request?
    request.user_agent.to_s.match?(MOBILE_OR_TABLET_USER_AGENT) ||
      request.headers["Sec-CH-UA-Mobile"] == "?1" ||
      request.headers["Sec-CH-UA-Platform"].to_s.match?(/\A(?:Android|iOS)\z/i)
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || root_path)
  end

  def track_last_login
    User.where(id: current_user.id).update_all(last_logged_in_at: Time.current)
  end
end
