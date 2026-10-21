class NotificationsController < ApplicationController`n  skip_before_action :verify_authenticity_token, only: [:dismiss]
  def dismiss
    if params[:do_not_show_again] == '1'
      NotificationDismissal.find_or_create_by(user: current_user, notification_id: params[:id])
    end
    redirect_back fallback_location: root_path
  end
end

