Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions"
  }

  authenticated :user do
    root to: "dashboard#index", as: :authenticated_root
  end
  root to: "pages#home"

  get "dashboard", to: "dashboard#index", as: :dashboard

  resources :competitors, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
    resources :analyses, only: [ :new, :create, :show ] do
      member do
        get :export_top_posts
      end
    end
    resources :story_observations, only: [ :new, :create, :index, :destroy ]
  end

  resources :own_profiles do
    member do
      post :sync
    end
    resources :own_posts, only: [ :index, :show, :edit, :update ]
  end

  resources :generated_medias, only: [ :index, :show ]

  namespace :content_suggestions do
    resources :generate, only: [ :create ]
  end

  resources :content_suggestions, only: [ :update ] do
    resource :video, only: [ :new ], controller: "content_suggestions/video"
    resources :generated_medias, only: [ :create ]
  end

  resources :playbooks do
    resources :playbook_versions, only: [ :index, :show ], shallow: true
    resources :playbook_feedbacks, only: [ :create, :update ], shallow: true do
      member do
        patch :incorporate
        patch :dismiss
      end
    end
    resources :playbook_suggestions, only: [ :create, :update ]
    member do
      get :export
      get :export_top_posts
    end
  end

  namespace :settings do
    resource :api_keys, only: [ :show ], controller: "api_keys" do
      post   "providers/:provider", to: "api_keys#create",  as: :create_for
      patch  "providers/:provider", to: "api_keys#update",  as: :update_for
      delete "providers/:provider", to: "api_keys#destroy", as: :destroy_for
    end
    resource :llm_preferences, only: [ :edit, :update ]
    resource :media_generation, only: [ :show, :update ], controller: "media_generation" do
      post :validate_key, on: :collection
      get :avatars
      get :voices
    end
  end

  # Webhooks externos — sem autenticação Devise, sem tenant
  namespace :webhooks do
    post :heygen, to: "heygen#receive"
  end

  get "up" => "rails/health#show", as: :rails_health_check

  unless Rails.env.production?
    get "design-system", to: "design_system#index"
  end
end
