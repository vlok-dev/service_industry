class Users::SessionsController < Devise::SessionsController
  private

  def after_sign_in_path_for(resource)
    username = resource.name.to_s.downcase.parameterize
    stored = stored_location_for(resource)
    stored || "/#{username}"
  end

  def after_sign_out_path_for(_resource)
    new_user_session_path
  end
end