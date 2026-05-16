Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#index"

  resources :import_batches, only: %i[index new create show]
  get "inventory", to: "inventory#index", as: :inventory
  get "inventory/items", to: "inventory#items", as: :inventory_items
  get "inventory/shopping-list", to: "inventory#shopping_list", as: :inventory_shopping_list
  get "inventory/counts", to: "inventory#counts", as: :inventory_counts
  get "inventory/counts/new", to: "inventory#new_count", as: :new_inventory_count
  post "inventory/counts", to: "inventory#create_count"
  resources :order_guides, only: :index do
    collection do
      post :import_current
    end
  end
  resources :products, only: %i[index show edit update]
  resources :receipt_line_items, only: %i[edit update]
  resources :normalization_reviews, only: %i[index] do
    member do
      patch :assign_product
      patch :create_product
      patch :resolve
    end
  end
  resources :reports, only: %i[index show]
end
