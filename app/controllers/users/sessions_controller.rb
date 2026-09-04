class Users::SessionsController < Devise::SessionsController
  def after_sign_in_path_for(resource)
    stored = stored_location_for(resource)
    stored || dashboard_path
  end

  def after_sign_out_path_for(_resource)
    new_user_session_path
  end
end