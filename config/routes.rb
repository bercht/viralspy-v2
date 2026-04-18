Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations"
  }

  authenticate :user do
    get "/dashboard", to: "dashboard#show", as: :dashboard
  end

  root to: redirect("/dashboard")

  get "up" => "rails/health#show", as: :rails_health_check
end
