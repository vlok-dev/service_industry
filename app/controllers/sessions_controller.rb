class SessionsController < ApplicationController
  def destroy
    session.clear
    cookies.each do |name, _|
      if name.start_with?("_industro_plumbers_")
        cookies.delete(name)
      end
    end
    redirect_to new_user_session_path, notice: "Signed out successfully."
  end
end