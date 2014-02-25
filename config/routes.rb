ItechService::Application.routes.draw do

  root to: 'dashboard#index'
  match 'dashboard' => 'dashboard#index', via: :get
  match 'become/:id' => 'dashboard#become', via: :get, as: 'become'
  match 'sign_in_by_card' => 'dashboard#sign_in_by_card', via: :get, as: 'sign_in_by_card'
  match 'actual_orders' => 'dashboard#actual_orders', via: :get
  match 'actual_tasks' => 'dashboard#actual_tasks', via: :get
  match 'actual_supply_requests' => 'dashboard#actual_supply_requests', via: :get
  match 'ready_devices' => 'dashboard#ready_devices', via: :get
  match 'goods_for_sale' => 'dashboard#goods_for_sale', via: :get
  match 'reports' => 'dashboard#reports', via: :get
  match 'check_session_status' => 'dashboard#check_session_status', via: :get

  mount Ckeditor::Engine => '/ckeditor'

  devise_for :users

  resources :departments

  resources :users do
    get :duty_calendar, on: :member
    get :schedule, on: :collection
    get :add_to_job_schedule, on: :member
    get :staff_duty_schedule, on: :collection
    get :rating, on: :collection
    get :actions, on: :member
    get :finance, on: :member
    get :bonuses, on: :member
    post :create_duty_day, on: :collection
    post :destroy_duty_day, on: :collection
  end

  resources :karmas do
    post :group, on: :collection, defaults: {format: 'js'}
    post :addtogroup, on: :collection, defaults: {format: 'js'}
    post :ungroup, on: :collection, defaults: {format: 'js'}
  end

  resources :karma_groups, except: [:new]

  match 'profile' => 'users#profile', via: :get
  match 'users/:id/update_wish' => 'users#update_wish', via: [:post, :put], as: 'update_wish_user'

  resources :clients do
    get :check_phone_number, on: :collection
    get :questionnaire, on: :collection
    get :autocomplete, on: :collection
    get :select, on: :member
    get :find, on: :member
  end

  resources :client_categories

  resources :device_types, except: [:new] do
    post :reserve, on: :member
  end

  resources :tasks
  resources :locations, except: :show
  
  resources :devices do
    get :history, on: :member, defaults: { format: 'js' }
    get :device_type_select, on: :collection, defaults: { format: 'js' }
    get :device_select, on: :collection
    get :check_imei, on: :collection
    get :movement_history, on: :member
    post :create_sale, on: :member
  end

  match 'check_device_status' => 'devices#check_status', via: :get
  match 'check_order_status' => 'orders#check_status', via: :get
  match 'devices/:device_id/device_tasks/:id/history' => 'devices#task_history', via: :get, as: :history_device_task, defaults: { format: 'js' }

  resources :device_tasks, only: [:edit, :update]

  resources :orders do
    get :history, on: :member, defaults: { format: 'js' }
    get :device_type_select, on: :collection, defaults: {format: 'js'}
  end

  resources :infos
  resources :stolen_phones, except: :show
  resources :prices

  resources :announcements do
    post :close, on: :member
    post :close_all, on: :collection
  end
  match 'make_announce' => 'announcements#make_announce', via: :post
  match 'cancel_announce' => 'announcements#cancel_announce', via: :post
  #match 'close_all' => 'announcements#close_all', via: :post

  resources :comments
  resources :messages, path: 'chat', except: [:new, :edit, :update]

  resources :purchases do
    put :post, on: :member
    put :unpost, on: :member
    put :print_barcodes, on: :member, defaults: {format: :pdf}
  end

  resources :sales do
    put :post, on: :member
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
  resources :bonuses
  resources :bonus_types, except: :show
  resources :installments
  resources :installment_plans
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

  resources :stores do
    get :product_details, on: :member, defaults: {format: :js}
  end

  resources :products do
    get :category_select, on: :collection, defaults: {format: :js}
    get :choose, on: :collection, defaults: {format: :js}
    get :show_prices, on: :member, defaults: {format: :js}
    get :show_remains, on: :member, defaults: {format: :js}
    get :remains_in_store, on: :member, defaults: {format: :json}
    get :related, on: :member, defaults: {format: :js}
    post :select, on: :collection, defaults: {format: :js}
    resources :items, except: [:show]
  end

  resources :items do
    get :remains_in_store, on: :member, defaults: {format: :json}
  end

  resources :product_groups
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

  resources :quick_orders do
    put :set_done, on: :member
  end

  resources :cash_shifts, only: :show do
    post :close, on: :member
  end

  resources :revaluation_acts do
    put 'post', on: :member
    put 'unpost', on: :member
  end

  resources :movement_acts do
    put 'post', on: :member
    put 'unpost', on: :member
    get 'make_defect_sp', on: :collection
  end

  resources :repair_services do
    get :choose, on: :collection, defaults: {format: :js}
    get :select, on: :member, defaults: {format: :js}
  end

  wiki_root '/wiki'

  match '/delayed_job' => DelayedJobWeb, anchor: false

  namespace :api, defaults: {format: 'json'} do
    namespace :v1 do
      match 'signin' => 'tokens#create', via: :post
      match 'signout' => 'tokens#destroy', via: :delete
      match 'scan/:barcode_num' => 'barcodes#scan'
      match 'profile' => 'users#profile'
      resources :products, only: [:index, :show] do
        post :sync, on: :collection
        get :remnants, on: :member
      end
      resources :items, only: [:index, :show]
      resources :devices, only: [:show, :update]
      resources :quick_orders, only: [:create]
    end
  end

end
