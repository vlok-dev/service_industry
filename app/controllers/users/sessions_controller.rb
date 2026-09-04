class Users::SessionsController < Devise::SessionsController
  prepend_before_action :require_no_authentication, only: [:new, :create, :stop_stay_logged_in]
  before_action :load_remembered_user, only: :new
  before_action :handle_stay_logged_in, only: :create

  def destroy
    cookies.each do |name, _|
      if name.start_with?("_industro_plumbers_")
        cookies.delete(name)
      end
    end
    super
  end

  def stop_stay_logged_in
    cookies.delete(:remembered_email, domain: :all)
    cookies.delete(:remembered_user, domain: :all)
    redirect_to new_user_session_path, notice: "Stay logged in has been cleared."
  end

  private

  def load_remembered_user
    @remembered_email = cookies[:remembered_email]
  end

  def handle_stay_logged_in
    if params[:stay_logged_in] == "1" && resource&.persisted?
      cookies.encrypted[:remembered_email] = {
        value: resource.email,
        expires: 30.days.from_now,
        httponly: true,
        same_site: :lax
      }
    end
  end

  def after_sign_in_path_for(resource)
    username = resource.name.to_s.downcase.parameterize
    stored = stored_location_for(resource)
    stored || "/#{username}"
  end

  def after_sign_out_path_for(_resource)
    new_user_session_path
  end
end