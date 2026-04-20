Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations"
  }

  authenticated :user do
    root to: "dashboard#index", as: :authenticated_root
  end
  root to: redirect("/users/sign_in")

  get "dashboard", to: "dashboard#index", as: :dashboard

  resources :competitors, only: [ :index, :new, :create, :show, :destroy ] do
    resources :analyses, only: [ :create, :show ]
  end

  resources :content_suggestions, only: [ :update ]

  get "up" => "rails/health#show", as: :rails_health_check

  unless Rails.env.production?
    get "design-system", to: "design_system#index"
  end
end
