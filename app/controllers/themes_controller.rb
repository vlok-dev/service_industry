class ThemesController < ApplicationController
  def update
    theme = params[:theme]
    current_user.update(theme_preference: theme) if %w[light dark].include?(theme)
    head :ok
  end
end
