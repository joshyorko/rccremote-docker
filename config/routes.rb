Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  get "up" => "rails/health#show", as: :rails_health_check

  root "dashboard#index"

  resources :robots, only: %i[index show create destroy] do
    post :upload, on: :member
    get :edit_files, on: :member
    patch :update_files, on: :member
  end

  resources :catalogs, only: %i[index] do
    post :rebuild, on: :collection
  end

  resources :hololib_zips,
            path: "hololib-zips",
            param: :filename,
            only: %i[index create destroy],
            constraints: { filename: /[^\/]+/ }

  namespace :api do
    resource :health, only: :show, controller: "health"
    resource :status, only: :show, controller: "status"
  end
end
