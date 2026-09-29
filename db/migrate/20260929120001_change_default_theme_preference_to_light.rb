class ChangeDefaultThemePreferenceToLight < ActiveRecord::Migration[8.1]
  def change
    change_column_default :users, :theme_preference, from: nil, to: "light"
  end
end
