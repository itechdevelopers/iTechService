require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  root to: 'dashboard#index'
  get 'dashboard', to: 'dashboard#index'
  get 'become/:id', to: 'dashboard#become', as: 'become'
  get 'actual_orders', to: 'dashboard#actual_orders'
  get 'actual_tasks', to: 'dashboard#actual_tasks'
  get 'actual_supply_requests', to: 'dashboard#actual_supply_requests'
  get 'ready_service_jobs', to: 'dashboard#ready_service_jobs'
  get 'check_session_status', to: 'dashboard#check_session_status'
  get 'print_tags', to: 'dashboard#print_tags'

  get 'app_logo', to: 'app_logo#edit'
  post 'app_logo', to: 'app_logo#update'

  resource :forma, controller: :forma, only: %i[new create show]

  devise_for :users, controllers: {
    sessions: 'users/sessions'
  }


  namespace :users, as: :user do
    devise_scope :user do
      post 'sign_in_by_card', to: 'sessions#sign_in_by_card'
    end
    resource :departments, only: %i[edit update], as: :department
  end

  namespace :service do
    resources :job_templates

    get :actual_feedbacks, to: 'actual_feedbacks#index', format: 'js'
    resources :feedbacks do
      put :postpone, on: :member
    end

    resources :free_tasks, only: %i[index new create edit update destroy]
    resources :free_jobs do
      get :performer_options, on: :collection
    end

    resources :repair_returns, only: %i[index new create]

    resources :sms_notifications, only: %i[new create]
  end

  resources :cities, except: :show
  resources :departments
  resources :brands, except: :show
  resources :reports, only: [:index, :new, :create]
  resources :reviews
  get   'review/:token', to: 'review#edit'
  patch 'review/:token', to: 'review#update'
  get :review, to: 'review#welcome'


  resources :users do
    get :duty_calendar, on: :member
    get :schedule, on: :collection
    get :add_to_job_schedule, on: :member
    get :staff_duty_schedule, on: :collection
    get :rating, on: :collection
    get :actions, on: :member
    get :finance, on: :member
    get :bonuses, on: :member
    get :experience, on: :collection, format: :js
    get :search, on: :collection, format: :json
    resources :faults, shallow: true, only: %i[index new create destroy]
    post :create_duty_day, on: :collection
    post :destroy_duty_day, on: :collection
    patch :update_uniform, on: :member
    patch :update_user_settings, on: :member
    patch :update_photo, on: :member
    patch :update_self, on: :member
    patch :update_elqueue_window, on: :member
  end

  resources :notifications, only: %i[destroy], defaults: { format: :js } do
    get :user_notifications, on: :collection, defaults: { format: :js }
    post :close, on: :member, defaults: { format: :js }
  end

  resources :dismissal_reasons, except: :show

  resources :faults, only: %i[new create]

  resources :karmas do
    post :group, on: :collection, defaults: {format: 'js'}
    post :addtogroup, on: :collection, defaults: {format: 'js'}
    post :ungroup, on: :collection, defaults: {format: 'js'}
  end

  resources :karma_groups, except: [:new]

  get 'profile', to: 'users#profile'
  match 'users/:id/update_wish' => 'users#update_wish', as: 'update_wish_user', via: %i[post patch]
  resources :favorite_links, except: :show

  resources :clients do
    get :check_phone_number, on: :collection
    get :questionnaire, on: :collection
    get :autocomplete, on: :collection
    get :select, on: :member
    get :find, on: :member
    get :show_caller, on: :member
    get :export, on: :collection
  end

  resources :client_categories

  resources :device_types, except: [:new] do
    post :reserve, on: :member
  end

  resources :tasks do
    scope module: 'tasks' do
      resource :device_validation, only: :show
    end
  end

  resources :locations, except: :show

  namespace :service_jobs do
    resource :inventory, only: %i[new show create]
  end

  resources :service_jobs do
    get :stale, on: :collection, format: 'js'
    get :history, on: :member, defaults: { format: 'js' }
    # get :inventory, on: :collection
    # post :inventory, on: :collection
    get :device_type_select, on: :collection, defaults: { format: 'js' }
    get :device_select, on: :collection
    get :check_imei, on: :collection
    get :movement_history, on: :member
    get :show_qr, on: :member, defaults: { format: 'js' }
    get :quick_search, on: :collection
    get :work_order, on: :member
    get :completion_act, on: :member
    post :create_sale, on: :member
    patch :set_keeper, on: :member, defaults: { format: 'js' }
    put :archive, on: :member, defaults: { format: 'js' }
    resources :device_notes, only: %i[index new create update], shallow: true
    scope module: :service_jobs do
      resource :subscription, only: %i[create destroy], format: :js
      resources :viewings, only: :index, format: :js
      resources :photos, format: :js, only: %i[show new create destroy]
    end
  end

  namespace :substitute_phones do
    get :stock, to: 'stock#index', format: :js
  end

  resources :substitute_phones, shallow: true do
    resources :substitutions, module: :substitute_phones, only: %i[new create edit update]
  end

  resources :devices do
    get :autocomplete, on: :collection
    get :select, on: :member
  end

  get 'check_device_status' => 'service_jobs#check_status'
  get 'check_order_status' => 'orders#check_status'
  get 'service_jobs/:service_job_id/device_tasks/:id/history' => 'service_jobs#task_history', as: :history_device_task, defaults: { format: 'js' }

  resources :device_tasks, only: [:edit, :update]

  resources :orders do
    patch :change_status, on: :member, defaults: { format: 'js' }
    get :history, on: :member, defaults: { format: 'js' }
    get :device_type_select, on: :collection, defaults: {format: 'js'}
    resources :order_notes, only: %i[index create update], shallow: true, defaults: { format: :js }
  end

  resources :infos
  resources :stolen_phones
  resources :prices

  resources :announcements do
    post :close, on: :member
    collection do
      post :close_all
      get :birthdays
      get :bad_reviews
    end
  end
  post 'make_announce' => 'announcements#make_announce'
  post 'cancel_announce' => 'announcements#cancel_announce'

  resources :comments
  resources :messages, path: 'chat', except: [:new, :edit, :update]

  resources :purchases do
    patch :post, on: :member
    patch :unpost, on: :member
    patch :print_barcodes, on: :member, defaults: {format: :pdf}
    patch :move_items, on: :member
    patch :revaluate_products, on: :member
  end

  resources :sales do
    patch :post, on: :member
    post :cancel, on: :member
    get :return_check, on: :member
    get :print_check, on: :member, defaults: {format: 'js'}
    get :print_warranty, on: :member
    post :attach_gift_certificate, on: :member, defaults: {format: 'js'}
    resources :payments
  end

  resources :sales_imports, only: [:new, :create]

  resources :gift_certificates do
    post :activate, on: :collection
    post :issue, on: :collection
    post :refresh, on: :member
    get :check, on: :collection
    get :scan, on: :collection
    get :find, on: :member
    get :history, on: :member, defaults: {format: 'js'}
  end

  resources :settings, except: [:show]
  resources :salaries
  resources :discounts, except: :show
  resources :timesheet_days, path: 'timesheet', except: :show
  resources :fault_kinds, except: :show
  resources :bonuses, except: :index
  resources :bonus_types, except: :show
  resources :installments, except: :index
  resources :installment_plans, except: :index
  resources :client_categories
  resources :supply_categories
  resources :supply_reports

  resources :supply_requests do
    post :make_done, on: :member
    post :make_new, on: :member
  end
  resources :product_categories, except: :show
  resources :features, except: :show
  resources :contractors
  resources :feature_types, except: :show
  resources :top_salables
  resources :task_templates

  resources :stores do
    get :product_details, on: :member, defaults: {format: :js}
  end

  resources :products do
    get :category_select, on: :collection, defaults: {format: :js}
    get :choose, on: :collection, defaults: {format: :js}
    get :choose_group, on: :collection, defaults: {format: :js}
    get :select_group, on: :collection, defaults: {format: :js}
    get :show_prices, on: :member, defaults: {format: :js}
    get :show_remains, on: :member, defaults: {format: :js}
    get :remains_in_store, on: :member, defaults: {format: :json}
    get :related, on: :member, defaults: {format: :js}
    post :select, on: :collection, defaults: {format: :js}
    get :find, on: :collection
    resources :items, except: [:show]
  end

  resources :items do
    get :autocomplete, on: :collection
    get :check_status, on: :member, defaults: {format: :json}
    get :remains_in_store, on: :member, defaults: {format: :json}
  end

  resources :product_groups do
    get :select, on: :member
  end

  resources :option_types, except: :show

  resources :product_types do
    get :select, on: :member
    resources :option_values, only: [:index]
  end

  resources :price_types, except: :show
  resources :payment_types
  resources :banks, except: :show
  resources :installments
  resources :installment_plans
  resources :cash_operations, only: [:index, :new, :create]
  resources :cash_drawers
  resources :repair_groups
  resources :case_colors, except: :show
  resources :quick_tasks, except: :show
  resources :product_imports, only: [:new, :create]
  resources :case_pictures, only: [:index, :new, :create]
  resources :carriers, except: [:show]
  resources :media_orders
  resources :contacts_extractions, only: [:new, :create]

  resources :quick_orders do
    patch :set_done, on: :member
    get :history, on: :member
  end

  resources :trade_in_devices do
    get :purgatory, on: :collection
    get :print, on: :member
  end

  resources :trade_in_device_evaluations, only: [:index] do
    put :bulk_update, on: :collection, defaults: { format: :js }
  end
  # Routes for ajax requests
  resources :trade_in_device_evaluations, only: [:new, :create, :destroy], defaults: { format: :js }

  resources :cash_shifts, only: :show do
    post :close, on: :member
  end

  resources :revaluation_acts do
    patch 'post', on: :member
    patch 'unpost', on: :member
  end

  resources :movement_acts do
    patch 'post', on: :member
    patch 'unpost', on: :member
    get 'make_defect_sp', on: :collection
  end

  resources :deduction_acts do
    patch 'post', on: :member
  end

  resources :repair_services do
    get :choose, on: :collection, defaults: {format: :js}
    get :select, on: :member, defaults: {format: :js}
    put :mass_update, on: :collection
  end

  resources :imported_sales, only: :index
  resources :sales_imports, only: [:new, :create]

  get 'receipts/new', as: :new_receipt
  get 'receipts/add_product'
  post 'receipts/print'

  namespace :kanban do
    resources :boards, shallow: true do
      resources :columns, shallow: true, except: %i[index show] do
        resources :cards
      end
      get :sorted, on: :member, defaults: {format: :js}
    end
  end

  namespace 'media_menu' do
    get '/', to: 'catalog#index'
    get 'items', to: 'items#index'
    get 'items/:id', to: 'items#show', as: 'item'
    resource 'order', only: %i[new create]
  end

  resources :wiki_pages, path: 'wiki' do
    resources :images, only: %i[create destroy]
    resources :documents, only: %i[create destroy], controller: 'wiki_documents'
    get :search, on: :collection, defaults: {format: :js}
  end

  resources :wiki_page_categories, only: %i[update destroy], defaults: {format: :js}

  resources :record_edits, only: %i[index]

  resources :reports_boards, only: %i[show] do
    patch :sort, on: :member, defaults: {format: :js}
    resources :report_columns, only: %i[create destroy], defaults: {format: :js}
  end

  resources :electronic_queues do
    resources :queue_items, except: %i[index show], defaults: {format: :js}
  end

  get 'elqueue/:permalink', to: 'electronic_queues#ipad_show', as: 'ipad_show'

  resources :waiting_clients, only: %i[create], defaults: {format: :js}

  resource :elqueue_windows, only: %i[update] do
    get :select_window, defaults: {format: :js}
  end

  authenticate :user do
    mount Sidekiq::Web => '/sidekiq'
  end

  mount API => '/'
  mount Ckeditor::Engine => '/ckeditor'
end
