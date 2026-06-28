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
    resources :tags, except: %i[show]
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Web Push opt-in: the service-worker subscribe flow POSTs a subscription and
  # DELETEs it (endpoint in the body) on opt-out.
  post   "push-subscriptions", to: "push_subscriptions#create",  as: :push_subscriptions
  delete "push-subscriptions", to: "push_subscriptions#destroy"

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
        collection do
          get :setup
        end

        member do
          patch :archive
          patch :reactivate
        end
      end
    end
  end

  resources :import_batches, only: %i[index new create show] do
    collection do
      get :csv_example
    end
  end
  get "inventory", to: "inventory#index", as: :inventory
  get "inventory/items", to: "inventory#items", as: :inventory_items
  get "inventory/shopping-list", to: "inventory#shopping_list", as: :inventory_shopping_list
  get "inventory/counts", to: "inventory#counts", as: :inventory_counts
  get "inventory/counts/new", to: "inventory#new_count", as: :new_inventory_count
  get "inventory/counts/:id", to: "inventory#count", as: :inventory_count, constraints: { id: /\d+/ }
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
  resources :recipes, only: %i[index show new create edit update] do
    resources :ingredients, only: %i[create update destroy], controller: "recipe_ingredients"
  end
  resources :photo_assets, path: "marketing/photos", only: %i[index new create show update destroy] do
    collection do
      post :bulk, to: "photo_asset_bulk_actions#create", as: :bulk_actions
    end
    member do
      patch :toggle_favorite
      get "crop/:style", to: "photo_asset_crops#show", as: :crop
      post :describe, to: "photo_asset_descriptions#create"
    end
    resources :taggings, only: %i[create destroy], controller: "photo_asset_taggings" do
      member do
        patch :confirm
      end
    end
    resources :collection_memberships, only: %i[create destroy]
  end
  # ZIP downloads: GET = a collection or the current filter, POST = a selection.
  get  "marketing/exports", to: "photo_asset_exports#show",   as: :photo_asset_exports
  post "marketing/exports", to: "photo_asset_exports#create"
  resources :collections, path: "marketing/collections" do
    resources :shares, only: %i[create destroy]
  end
  # Public, login-free shared collection galleries.
  get "share/:token",          to: "public/shared_collections#show",     as: :shared_collection
  get "share/:token/download", to: "public/shared_collections#download", as: :shared_collection_download
  get "marketing", to: redirect("/marketing/photos")
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
