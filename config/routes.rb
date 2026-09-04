Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions"
  }
  get "/stop_stay_logged_in" => "users/sessions#stop_stay_logged_in", as: :stop_stay_logged_in
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect("/users/sign_in")

  scope "/:username" do
    get "/" => "dashboard#index", as: "dashboard"
    delete "/logout" => "sessions#destroy", as: "logout"

    resources :jobs do
      member do
        patch :schedule
        get :whatsapp
      end
      collection do
        get :bulk_whatsapp
      end
      resources :purchase_orders, only: [:new, :create, :show, :edit, :update, :destroy]
    end

    get "/calendar" => "calendars#index", as: :calendar
    get "/calendar/previous" => "calendars#previous_date", as: :calendar_previous
    get "/calendar/next" => "calendars#next_date", as: :calendar_next

    namespace :admin do
      root to: "dashboard#index"
      resources :users
      resource :settings, only: [:edit, :update]
    end
  end
end