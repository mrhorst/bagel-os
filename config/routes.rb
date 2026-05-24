Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :account, only: %i[show update]
  patch "account/password", to: "accounts#update_password", as: :account_password

  namespace :admin do
    resources :users, except: %i[show] do
      member do
        post :transfer_ownership
      end
    end
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "dashboard#index"

  # Mobile bottom-nav group hubs. Each hub shows the modules in its group.
  get "shift",  to: "hubs#shift",  as: :shift_hub
  get "stock",  to: "hubs#stock",  as: :stock_hub
  get "buying", to: "hubs#buying", as: :buying_hub
  get "more",   to: "hubs#more",   as: :more_hub

  get "log-book", to: "log_book#index", as: :log_book
  patch "log-book", to: "log_book#update"
  get "log-book/settings", to: "log_book_settings#index", as: :log_book_settings
  get "log-book/history", to: "log_book_history#index", as: :log_book_history
  resources :log_book_sections, path: "log-book/sections", except: %i[show destroy] do
    member do
      patch :archive
      patch :reactivate
    end
  end
  resources :log_book_responses, path: "log-book/responses", only: [] do
    member do
      patch :resolve
    end
  end

  resources :follow_ups, path: "follow-ups", only: %i[index show] do
    member do
      patch :resolve
      patch :reopen
      patch :assign
      post  :spawn_task
    end
    resources :notes, only: :create, controller: "follow_up_notes"
  end

  scope module: :tasks, path: :tasks, as: :tasks do
    # ── Work surface (read-mostly, used during shift) ───────────────────
    root "dashboard#index"
    get "history", to: "history#index", as: :history

    # Focused single-list view — the “open my Prep list” entry point.
    resources :task_lists, path: "lists", as: "lists", only: %i[show]

    resources :occurrences, only: %i[show] do
      resource :completion, only: %i[create destroy], controller: "completions"
    end

    # ── Settings (write-mostly, used between shifts) ────────────────────
    # /tasks/manage is the hub; the three sub-pages live beneath it.
    get "manage", to: "settings#index", as: :manage

    scope path: "manage", as: :manage do
      # Each task and list has its own real URL: /tasks/manage/(tasks|lists)/:id/edit
      resources :task_lists, path: "lists", as: "lists", only: %i[index new create edit update] do
        member do
          patch :archive
          patch :reactivate
        end
      end

      resources :tasks, controller: "manage", only: %i[index new create edit update] do
        member do
          patch :archive
          patch :reactivate
        end
      end
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
      patch :skip
    end
  end
  resources :reports, only: %i[index show]
end
