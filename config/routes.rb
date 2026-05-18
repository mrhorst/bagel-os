Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#index"

  scope module: :tasks, path: :tasks, as: :tasks do
    root "dashboard#index"
    patch "completing-as", to: "completing_as#update", as: :completing_as
    get "history", to: "history#index", as: :history
    resources :staff_members, path: "staff", as: "staff", only: %i[index create update] do
      member do
        patch :deactivate
        patch :reactivate
      end
    end
    resources :task_lists, path: "lists", as: "lists", only: %i[index create update] do
      member do
        patch :archive
        patch :reactivate
      end
    end
    get "manage", to: "manage#index", as: :manage
    post "manage", to: "manage#create"
    patch "manage/:id", to: "manage#update", as: :managed_task
    patch "manage/:id/archive", to: "manage#archive", as: :archive_managed_task
    patch "manage/:id/reactivate", to: "manage#reactivate", as: :reactivate_managed_task
    resources :occurrences, only: %i[show] do
      resource :completion, only: %i[create destroy], controller: "completions"
    end
  end

  resources :import_batches, only: %i[index new create show]
  get "inventory", to: "inventory#index", as: :inventory
  get "inventory/items", to: "inventory#items", as: :inventory_items
  get "inventory/shopping-list", to: "inventory#shopping_list", as: :inventory_shopping_list
  get "inventory/counts", to: "inventory#counts", as: :inventory_counts
  get "inventory/counts/new", to: "inventory#new_count", as: :new_inventory_count
  post "inventory/counts", to: "inventory#create_count"
  patch "inventory/items/:id/primary-order-guide", to: "inventory#update_primary_order_guide", as: :inventory_item_primary_order_guide
  resources :order_guides, only: %i[index show create update destroy] do
    collection do
      get :csv_example
    end
    resources :memberships, only: %i[create update destroy], controller: "order_guide_memberships"
  end
  resources :products, only: %i[index show edit update] do
    resources :order_guide_memberships, only: %i[create], controller: "product_order_guide_memberships"
  end
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
