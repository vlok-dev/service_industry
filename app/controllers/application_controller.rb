class ApplicationController < ActionController::Base
  include Pundit::Authorization
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_session_scope
  before_action :authenticate_user!
  before_action :enforce_username_scope
  before_action :configure_permitted_parameters, if: :devise_controller?

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [:name, :role, :phone_number])
    devise_parameter_sanitizer.permit(:account_update, keys: [:name, :role, :phone_number])
  end

  private

  def set_session_scope
    @username = params[:username]
    return unless @username.present?

    old_key = request.session_options[:key]
    new_key = "_industro_plumbers_#{@username}_session"

    if old_key != new_key
      # Access session to load it from the old cookie
      warden_key = session["warden.user.user.key"]

      # Switch to the new session key
      request.session_options[:key] = new_key

      # Migrate warden session data from old cookie to new cookie
      if warden_key.present? && session["warden.user.user.key"] != warden_key
        session["warden.user.user.key"] = warden_key
      end
    end
  end

  def enforce_username_scope
    return unless current_user && @username
    expected_username = current_user.name.to_s.downcase.parameterize
    unless @username == expected_username
      redirect_to "/#{expected_username}", alert: "You can only access your own workspace."
    end
  end

  def default_url_options
    @username.present? ? { username: @username } : {}
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_to(request.referrer || "/#{current_user&.name&.downcase&.parameterize || 'users/sign_in'}")
  end
end
