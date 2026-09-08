Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions"
  }
  get "/stop_stay_logged_in" => "users/sessions#stop_stay_logged_in", as: :stop_stay_logged_in

  get "up" => "rails/health#show", as: :rails_health_check

  root to: redirect("/users/sign_in")

  get "/dashboard" => "dashboard#index", as: :dashboard

  resources :jobs do
    member do
      patch :schedule
      patch :add_extra_day
      patch :close
      patch :update_status
      patch :update_job_type
      get :whatsapp
      post :confirm_whatsapp
    end
    collection do
      get :bulk_whatsapp
    end
    resources :purchase_orders, only: [:new, :create, :show, :edit, :update, :destroy]
    resources :claims
  end

  resources :suppliers
  resources :clients do
    collection do
      get :import
      post :import_create
      delete :delete_all
    end
  end
  resources :inventory_items do
    collection do
      get :search
      get :import
      post :import_create
    end
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