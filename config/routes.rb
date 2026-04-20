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
    resources :analyses, only: [ :new, :create, :show ]
  end

  resources :content_suggestions, only: [ :update ]

  resources :playbooks do
    resources :playbook_versions, only: [ :index, :show ], shallow: true
    resources :playbook_feedbacks, only: [ :create, :update ], shallow: true do
      member do
        patch :incorporate
        patch :dismiss
      end
    end
    member do
      get :export
    end
  end

  namespace :settings do
    resource :api_keys, only: [ :show ], controller: "api_keys" do
      post   "providers/:provider", to: "api_keys#create",  as: :create_for
      patch  "providers/:provider", to: "api_keys#update",  as: :update_for
      delete "providers/:provider", to: "api_keys#destroy", as: :destroy_for
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  unless Rails.env.production?
    get "design-system", to: "design_system#index"
  end
end
