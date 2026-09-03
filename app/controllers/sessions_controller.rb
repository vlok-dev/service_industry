class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:destroy]
  skip_before_action :enforce_username_scope, only: [:destroy]

  def destroy
    cookies.each do |name, _|
      if name.start_with?("_industro_plumbers_")
        cookies.delete(name)
      end
    end
    sign_out(current_user) if current_user
    session.clear
    redirect_to new_user_session_path, notice: "Signed out successfully."
  end
end