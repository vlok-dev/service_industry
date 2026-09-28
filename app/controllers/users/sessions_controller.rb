class Users::SessionsController < Devise::SessionsController
  skip_before_action :verify_authenticity_token, only: [ :create, :destroy ]

  def new
    super
    @remembered_email = params[:email].presence || cookies[:email].presence
  end

  def stop_stay_logged_in
    cookies.delete(:email)
    redirect_to new_user_session_path, notice: "Email cleared."
  end

  def after_sign_in_path_for(resource)
    stored = stored_location_for(resource)
    stored || dashboard_path
  end

  # When someone switches between the roles they hold, send them to the sign-in
  # screen with that role's login already filled in.
  def after_sign_out_path_for(_resource)
    new_user_session_path(email: params[:email])
  end
end
