class ThemesController < ApplicationController
  def update
    theme = params[:theme]
    current_user.update(theme_preference: theme) if %w[light dark].include?(theme)
    head :ok
  end

  def update_sidebar
    collapsed = params[:collapsed] == true || params[:collapsed] == "true"
    current_user.update(sidebar_collapsed: collapsed)
    head :ok
  end
end
