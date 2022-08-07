# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20220728210730) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "announcements", force: :cascade do |t|
    t.string "content"
    t.string "kind", null: false
    t.bigint "user_id"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.index ["department_id"], name: "index_announcements_on_department_id"
    t.index ["kind"], name: "index_announcements_on_kind"
    t.index ["user_id"], name: "index_announcements_on_user_id"
  end

  create_table "announcements_users", force: :cascade do |t|
    t.bigint "announcement_id"
    t.bigint "user_id"
    t.index ["announcement_id"], name: "index_announcements_users_on_announcement_id"
    t.index ["user_id"], name: "index_announcements_users_on_user_id"
  end

  create_table "banks", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "batches", force: :cascade do |t|
    t.bigint "purchase_id"
    t.bigint "item_id"
    t.decimal "price", precision: 8, scale: 2
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_batches_on_item_id"
    t.index ["purchase_id"], name: "index_batches_on_purchase_id"
  end

  create_table "bonus_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bonuses", force: :cascade do |t|
    t.bigint "bonus_type_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bonus_type_id"], name: "index_bonuses_on_bonus_type_id"
  end

  create_table "brands", force: :cascade do |t|
    t.string "name", null: false
    t.string "logo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "carriers", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "case_colors", force: :cascade do |t|
    t.string "name"
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cash_drawers", force: :cascade do |t|
    t.string "name"
    t.bigint "department_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_cash_drawers_on_department_id"
  end

  create_table "cash_operations", force: :cascade do |t|
    t.bigint "cash_shift_id"
    t.bigint "user_id"
    t.boolean "is_out", default: false
    t.decimal "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "comment"
    t.index ["cash_shift_id"], name: "index_cash_operations_on_cash_shift_id"
    t.index ["user_id"], name: "index_cash_operations_on_user_id"
  end

  create_table "cash_shifts", force: :cascade do |t|
    t.boolean "is_closed", default: false
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "closed_at"
    t.integer "cash_drawer_id"
    t.index ["cash_drawer_id"], name: "index_cash_shifts_on_cash_drawer_id"
    t.index ["user_id"], name: "index_cash_shifts_on_user_id"
  end

  create_table "cities", force: :cascade do |t|
    t.string "name", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "time_zone"
  end

  create_table "ckeditor_assets", force: :cascade do |t|
    t.string "data_file_name", null: false
    t.string "data_content_type"
    t.integer "data_file_size"
    t.integer "assetable_id"
    t.string "assetable_type", limit: 30
    t.string "type", limit: 30
    t.integer "width"
    t.integer "height"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assetable_type", "assetable_id"], name: "idx_ckeditor_assetable"
    t.index ["assetable_type", "type", "assetable_id"], name: "idx_ckeditor_assetable_type"
  end

  create_table "client_categories", force: :cascade do |t|
    t.string "name"
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "client_characteristics", force: :cascade do |t|
    t.bigint "client_category_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_category_id"], name: "index_client_characteristics_on_client_category_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "name"
    t.string "phone_number"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "card_number"
    t.string "full_phone_number"
    t.string "surname"
    t.string "patronymic"
    t.date "birthday"
    t.string "email"
    t.text "admin_info"
    t.string "contact_phone"
    t.integer "category"
    t.integer "client_characteristic_id"
    t.integer "department_id"
    t.index ["card_number"], name: "index_clients_on_card_number"
    t.index ["category"], name: "index_clients_on_category"
    t.index ["department_id"], name: "index_clients_on_department_id"
    t.index ["email"], name: "index_clients_on_email"
    t.index ["full_phone_number"], name: "index_clients_on_full_phone_number"
    t.index ["name"], name: "index_clients_on_name"
    t.index ["patronymic"], name: "index_clients_on_patronymic"
    t.index ["phone_number"], name: "index_clients_on_phone_number"
    t.index ["surname"], name: "index_clients_on_surname"
  end

  create_table "comments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "commentable_type", null: false
    t.bigint "commentable_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commentable_id", "commentable_type"], name: "index_comments_on_commentable_id_and_commentable_type"
    t.index ["commentable_id"], name: "index_comments_on_commentable_id"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "contractors", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "deduction_acts", force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.datetime "date"
    t.bigint "store_id"
    t.bigint "user_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id"], name: "index_deduction_acts_on_store_id"
    t.index ["user_id"], name: "index_deduction_acts_on_user_id"
  end

  create_table "deduction_items", force: :cascade do |t|
    t.bigint "item_id", null: false
    t.bigint "deduction_act_id"
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deduction_act_id"], name: "index_deduction_items_on_deduction_act_id"
    t.index ["item_id"], name: "index_deduction_items_on_item_id"
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0
    t.integer "attempts", default: 0
    t.text "handler"
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "departments", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.integer "role"
    t.string "url"
    t.string "address"
    t.string "contact_phone"
    t.text "schedule"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "printer"
    t.string "ip_network"
    t.boolean "archive", default: false
    t.bigint "city_id"
    t.bigint "brand_id"
    t.string "short_name"
    t.index ["brand_id"], name: "index_departments_on_brand_id"
    t.index ["city_id"], name: "index_departments_on_city_id"
    t.index ["code"], name: "index_departments_on_code"
    t.index ["role"], name: "index_departments_on_role"
  end

  create_table "device_notes", force: :cascade do |t|
    t.bigint "service_job_id", null: false
    t.bigint "user_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_job_id"], name: "index_device_notes_on_service_job_id"
    t.index ["user_id"], name: "index_device_notes_on_user_id"
  end

  create_table "device_tasks", force: :cascade do |t|
    t.bigint "service_job_id"
    t.bigint "task_id"
    t.integer "done", default: 0
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "cost"
    t.datetime "done_at"
    t.text "user_comment"
    t.integer "performer_id"
    t.index ["done"], name: "index_device_tasks_on_done"
    t.index ["done_at"], name: "index_device_tasks_on_done_at"
    t.index ["performer_id"], name: "index_device_tasks_on_performer_id"
    t.index ["service_job_id"], name: "index_device_tasks_on_service_job_id"
    t.index ["task_id"], name: "index_device_tasks_on_task_id"
  end

  create_table "device_types", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ancestry"
    t.integer "qty_for_replacement", default: 0
    t.integer "qty_replaced", default: 0
    t.integer "qty_shop"
    t.integer "qty_store"
    t.integer "qty_reserve"
    t.integer "expected_during"
    t.integer "code_1c"
    t.index ["ancestry"], name: "index_device_types_on_ancestry"
    t.index ["code_1c"], name: "index_device_types_on_code_1c"
    t.index ["name"], name: "index_device_types_on_name"
  end

  create_table "discounts", force: :cascade do |t|
    t.integer "value"
    t.integer "limit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["limit"], name: "index_discounts_on_limit"
  end

  create_table "duty_days", force: :cascade do |t|
    t.bigint "user_id"
    t.date "day"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "kind"
    t.index ["day"], name: "index_duty_days_on_day"
    t.index ["kind"], name: "index_duty_days_on_kind"
    t.index ["user_id"], name: "index_duty_days_on_user_id"
  end

  create_table "fault_kinds", force: :cascade do |t|
    t.string "name"
    t.string "icon"
    t.boolean "is_permanent", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.boolean "financial", default: false, null: false
    t.string "penalties"
  end

  create_table "faults", force: :cascade do |t|
    t.bigint "causer_id", null: false
    t.bigint "kind_id", null: false
    t.date "date"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "penalty"
    t.index ["causer_id"], name: "index_faults_on_causer_id"
    t.index ["kind_id"], name: "index_faults_on_kind_id"
  end

  create_table "favorite_links", force: :cascade do |t|
    t.bigint "owner_id", null: false
    t.string "name"
    t.string "url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_favorite_links_on_owner_id"
  end

  create_table "feature_types", force: :cascade do |t|
    t.string "name"
    t.string "kind"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_feature_types_on_kind"
  end

  create_table "feature_types_product_categories", force: :cascade do |t|
    t.bigint "product_category_id"
    t.bigint "feature_type_id"
    t.index ["feature_type_id"], name: "index_feature_types_product_categories_on_feature_type_id"
    t.index ["product_category_id"], name: "index_feature_types_product_categories_on_product_category_id"
  end

  create_table "features", force: :cascade do |t|
    t.bigint "feature_type_id"
    t.bigint "item_id"
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_type_id"], name: "index_features_on_feature_type_id"
    t.index ["item_id"], name: "index_features_on_item_id"
    t.index ["value"], name: "index_features_on_value"
  end

  create_table "features_items", force: :cascade do |t|
    t.bigint "feature_id"
    t.bigint "item_id"
    t.index ["feature_id"], name: "index_features_items_on_feature_id"
    t.index ["item_id"], name: "index_features_items_on_item_id"
  end

  create_table "gift_certificates", force: :cascade do |t|
    t.string "number"
    t.integer "nominal"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "consumed"
    t.integer "department_id"
    t.index ["department_id"], name: "index_gift_certificates_on_department_id"
    t.index ["number"], name: "index_gift_certificates_on_number"
  end

  create_table "history_records", force: :cascade do |t|
    t.bigint "user_id"
    t.string "object_type"
    t.bigint "object_id"
    t.string "column_name"
    t.string "column_type"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "old_value"
    t.text "new_value"
    t.index ["column_name"], name: "index_history_records_on_column_name"
    t.index ["object_id", "object_type"], name: "index_history_records_on_object_id_and_object_type"
    t.index ["object_type", "object_id"], name: "index_history_records_on_object_type_and_object_id"
    t.index ["user_id"], name: "index_history_records_on_user_id"
  end

  create_table "imported_sales", force: :cascade do |t|
    t.bigint "device_type_id"
    t.string "imei"
    t.string "serial_number"
    t.datetime "sold_at"
    t.string "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_type_id"], name: "index_imported_sales_on_device_type_id"
    t.index ["imei"], name: "index_imported_sales_on_imei"
    t.index ["quantity"], name: "index_imported_sales_on_quantity"
    t.index ["serial_number"], name: "index_imported_sales_on_serial_number"
    t.index ["sold_at"], name: "index_imported_sales_on_sold_at"
  end

  create_table "infos", force: :cascade do |t|
    t.string "title", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "important", default: false
    t.integer "recipient_id"
    t.boolean "is_archived", default: false
    t.integer "department_id"
    t.index ["department_id"], name: "index_infos_on_department_id"
    t.index ["recipient_id"], name: "index_infos_on_recipient_id"
    t.index ["title"], name: "index_infos_on_title"
  end

  create_table "installment_plans", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "object"
    t.integer "cost"
    t.date "issued_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_closed", default: false
    t.index ["is_closed"], name: "index_installment_plans_on_is_closed"
    t.index ["user_id"], name: "index_installment_plans_on_user_id"
  end

  create_table "installments", force: :cascade do |t|
    t.bigint "installment_plan_id"
    t.integer "value"
    t.date "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["installment_plan_id"], name: "index_installments_on_installment_plan_id"
  end

  create_table "items", force: :cascade do |t|
    t.bigint "product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "barcode_num"
    t.index ["barcode_num"], name: "index_items_on_barcode_num"
    t.index ["product_id"], name: "index_items_on_product_id"
  end

  create_table "karma_groups", force: :cascade do |t|
    t.bigint "bonus_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bonus_id"], name: "index_karma_groups_on_bonus_id"
  end

  create_table "karmas", force: :cascade do |t|
    t.boolean "good"
    t.text "comment"
    t.bigint "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "karma_group_id"
    t.index ["karma_group_id"], name: "index_karmas_on_karma_group_id"
    t.index ["user_id"], name: "index_karmas_on_user_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name"
    t.string "ancestry"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "schedule"
    t.integer "position", default: 0
    t.string "code"
    t.integer "department_id"
    t.boolean "hidden", default: false
    t.integer "storage_term"
    t.index ["ancestry"], name: "index_locations_on_ancestry"
    t.index ["code"], name: "index_locations_on_code"
    t.index ["department_id"], name: "index_locations_on_department_id"
    t.index ["name"], name: "index_locations_on_name"
    t.index ["schedule"], name: "index_locations_on_schedule"
  end

  create_table "lost_devices", force: :cascade do |t|
    t.bigint "service_job_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_job_id"], name: "index_lost_devices_on_service_job_id", unique: true
  end

  create_table "media_orders", force: :cascade do |t|
    t.datetime "time"
    t.string "name"
    t.string "phone"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "user_id"
    t.string "content"
    t.string "recipient_type"
    t.bigint "recipient_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "department_id", null: false
    t.index ["department_id"], name: "index_messages_on_department_id"
    t.index ["recipient_id"], name: "index_messages_on_recipient_id"
    t.index ["recipient_type", "recipient_id"], name: "index_messages_on_recipient_type_and_recipient_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "movement_acts", force: :cascade do |t|
    t.datetime "date"
    t.integer "store_id"
    t.integer "dst_store_id"
    t.integer "user_id"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "comment"
    t.index ["dst_store_id"], name: "index_movement_acts_on_dst_store_id"
    t.index ["store_id"], name: "index_movement_acts_on_store_id"
    t.index ["user_id"], name: "index_movement_acts_on_user_id"
  end

  create_table "movement_items", force: :cascade do |t|
    t.bigint "movement_act_id"
    t.bigint "item_id"
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_movement_items_on_item_id"
    t.index ["movement_act_id"], name: "index_movement_items_on_movement_act_id"
  end

  create_table "option_types", force: :cascade do |t|
    t.string "name", null: false
    t.string "code"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_option_types_on_code"
    t.index ["name"], name: "index_option_types_on_name"
  end

  create_table "option_values", force: :cascade do |t|
    t.bigint "option_type_id", null: false
    t.string "name", null: false
    t.string "code"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_option_values_on_code"
    t.index ["name"], name: "index_option_values_on_name"
    t.index ["option_type_id"], name: "index_option_values_on_option_type_id"
  end

  create_table "order_notes", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "author_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_order_notes_on_author_id"
    t.index ["order_id"], name: "index_order_notes_on_order_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "number"
    t.string "customer_type"
    t.bigint "customer_id"
    t.string "object_kind"
    t.string "object"
    t.date "desired_date"
    t.string "status"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.text "user_comment"
    t.integer "department_id"
    t.integer "quantity", default: 1
    t.integer "priority", default: 1
    t.decimal "approximate_price"
    t.text "object_url"
    t.text "model"
    t.integer "prepayment"
    t.integer "payment_method"
    t.string "picture"
    t.index ["customer_id", "customer_type"], name: "index_orders_on_customer_id_and_customer_type"
    t.index ["customer_id"], name: "index_orders_on_customer_id"
    t.index ["customer_type", "customer_id"], name: "index_orders_on_customer_type_and_customer_id"
    t.index ["department_id"], name: "index_orders_on_department_id"
    t.index ["object_kind"], name: "index_orders_on_object_kind"
    t.index ["priority"], name: "index_orders_on_priority"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "payment_types", force: :cascade do |t|
    t.string "name"
    t.string "kind"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_payment_types_on_kind"
  end

  create_table "payments", force: :cascade do |t|
    t.string "kind"
    t.decimal "value"
    t.bigint "sale_id"
    t.bigint "bank_id"
    t.bigint "gift_certificate_id"
    t.string "device_name"
    t.string "device_number"
    t.string "client_info"
    t.string "appraiser"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_id"], name: "index_payments_on_bank_id"
    t.index ["gift_certificate_id"], name: "index_payments_on_gift_certificate_id"
    t.index ["kind"], name: "index_payments_on_kind"
    t.index ["sale_id"], name: "index_payments_on_sale_id"
  end

  create_table "phone_substitutions", force: :cascade do |t|
    t.bigint "substitute_phone_id", null: false
    t.bigint "service_job_id", null: false
    t.bigint "issuer_id", null: false
    t.datetime "issued_at", null: false
    t.bigint "receiver_id"
    t.boolean "condition_match"
    t.datetime "withdrawn_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["issuer_id"], name: "index_phone_substitutions_on_issuer_id"
    t.index ["receiver_id"], name: "index_phone_substitutions_on_receiver_id"
    t.index ["service_job_id"], name: "index_phone_substitutions_on_service_job_id"
    t.index ["substitute_phone_id"], name: "index_phone_substitutions_on_substitute_phone_id"
  end

  create_table "price_types", force: :cascade do |t|
    t.string "name"
    t.integer "kind"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_price_types_on_kind"
  end

  create_table "price_types_stores", force: :cascade do |t|
    t.bigint "price_type_id"
    t.bigint "store_id"
    t.index ["price_type_id"], name: "index_price_types_stores_on_price_type_id"
    t.index ["store_id"], name: "index_price_types_stores_on_store_id"
  end

  create_table "prices", force: :cascade do |t|
    t.string "file"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.index ["department_id"], name: "index_prices_on_department_id"
  end

  create_table "product_categories", force: :cascade do |t|
    t.string "name"
    t.boolean "feature_accounting", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "warranty_term"
    t.string "kind"
    t.boolean "request_price"
    t.index ["kind"], name: "index_product_categories_on_kind"
  end

  create_table "product_groups", force: :cascade do |t|
    t.string "name"
    t.string "ancestry"
    t.bigint "product_category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ancestry_depth", default: 0
    t.string "code"
    t.integer "position", default: 0, null: false
    t.integer "warranty_term", default: 0, null: false
    t.index ["ancestry"], name: "index_product_groups_on_ancestry"
    t.index ["code"], name: "index_product_groups_on_code"
    t.index ["product_category_id"], name: "index_product_groups_on_product_category_id"
  end

  create_table "product_groups_option_values", id: false, force: :cascade do |t|
    t.bigint "product_group_id"
    t.bigint "option_value_id"
    t.index ["option_value_id"], name: "index_product_groups_option_values_on_option_value_id"
    t.index ["product_group_id"], name: "index_product_groups_option_values_on_product_group_id"
  end

  create_table "product_options", id: false, force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "option_value_id", null: false
    t.index ["option_value_id"], name: "index_product_options_on_option_value_id"
    t.index ["product_id"], name: "index_product_options_on_product_id"
  end

  create_table "product_prices", force: :cascade do |t|
    t.bigint "product_id"
    t.bigint "price_type_id"
    t.datetime "date"
    t.decimal "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.index ["department_id"], name: "index_product_prices_on_department_id"
    t.index ["price_type_id"], name: "index_product_prices_on_price_type_id"
    t.index ["product_id"], name: "index_product_prices_on_product_id"
  end

  create_table "product_relations", force: :cascade do |t|
    t.string "parent_type"
    t.bigint "parent_id"
    t.string "relatable_type"
    t.bigint "relatable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_type", "parent_id"], name: "index_product_relations_on_parent_type_and_parent_id"
    t.index ["relatable_type", "relatable_id"], name: "index_product_relations_on_relatable_type_and_relatable_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.string "code"
    t.bigint "product_group_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "warranty_term"
    t.integer "device_type_id"
    t.integer "quantity_threshold"
    t.text "comment"
    t.integer "product_category_id"
    t.string "barcode_num"
    t.index ["barcode_num"], name: "index_products_on_barcode_num"
    t.index ["code"], name: "index_products_on_code"
    t.index ["device_type_id"], name: "index_products_on_device_type_id"
    t.index ["name"], name: "index_products_on_name"
    t.index ["product_category_id"], name: "index_products_on_product_category_id"
    t.index ["product_group_id"], name: "index_products_on_product_group_id"
  end

  create_table "purchases", force: :cascade do |t|
    t.bigint "contractor_id"
    t.bigint "store_id"
    t.datetime "date"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "comment"
    t.boolean "skip_revaluation"
    t.index ["contractor_id"], name: "index_purchases_on_contractor_id"
    t.index ["status"], name: "index_purchases_on_status"
    t.index ["store_id"], name: "index_purchases_on_store_id"
  end

  create_table "quick_orders", force: :cascade do |t|
    t.integer "number"
    t.boolean "is_done"
    t.bigint "user_id"
    t.string "client_name"
    t.string "contact_phone"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "security_code"
    t.integer "department_id"
    t.string "device_kind"
    t.bigint "client_id"
    t.index ["client_id"], name: "index_quick_orders_on_client_id"
    t.index ["client_name"], name: "index_quick_orders_on_client_name"
    t.index ["contact_phone"], name: "index_quick_orders_on_contact_phone"
    t.index ["department_id"], name: "index_quick_orders_on_department_id"
    t.index ["number"], name: "index_quick_orders_on_number"
    t.index ["user_id"], name: "index_quick_orders_on_user_id"
  end

  create_table "quick_orders_quick_tasks", id: false, force: :cascade do |t|
    t.bigint "quick_order_id"
    t.bigint "quick_task_id"
    t.index ["quick_order_id", "quick_task_id"], name: "index_quick_orders_tasks"
    t.index ["quick_order_id"], name: "index_quick_orders_quick_tasks_on_quick_order_id"
    t.index ["quick_task_id"], name: "index_quick_orders_quick_tasks_on_quick_task_id"
  end

  create_table "quick_tasks", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "repair_groups", force: :cascade do |t|
    t.string "name"
    t.string "ancestry"
    t.integer "ancestry_depth", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestry"], name: "index_repair_groups_on_ancestry"
  end

  create_table "repair_parts", force: :cascade do |t|
    t.bigint "repair_task_id"
    t.bigint "item_id"
    t.integer "quantity"
    t.integer "warranty_term"
    t.integer "defect_qty"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_repair_parts_on_item_id"
    t.index ["repair_task_id"], name: "index_repair_parts_on_repair_task_id"
  end

  create_table "repair_prices", force: :cascade do |t|
    t.bigint "repair_service_id"
    t.bigint "department_id"
    t.decimal "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_repair_prices_on_department_id"
    t.index ["repair_service_id"], name: "index_repair_prices_on_repair_service_id"
  end

  create_table "repair_services", force: :cascade do |t|
    t.bigint "repair_group_id"
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "client_info"
    t.boolean "is_positive_price", default: false
    t.boolean "difficult", default: false
    t.boolean "is_body_repair", default: false
    t.index ["repair_group_id"], name: "index_repair_services_on_repair_group_id"
  end

  create_table "repair_tasks", force: :cascade do |t|
    t.bigint "repair_service_id"
    t.bigint "device_task_id"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "store_id"
    t.bigint "repairer_id"
    t.index ["device_task_id"], name: "index_repair_tasks_on_device_task_id"
    t.index ["repair_service_id"], name: "index_repair_tasks_on_repair_service_id"
    t.index ["repairer_id"], name: "index_repair_tasks_on_repairer_id"
    t.index ["store_id"], name: "index_repair_tasks_on_store_id"
  end

  create_table "revaluation_acts", force: :cascade do |t|
    t.bigint "price_type_id"
    t.datetime "date"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["price_type_id"], name: "index_revaluation_acts_on_price_type_id"
    t.index ["status"], name: "index_revaluation_acts_on_status"
  end

  create_table "revaluations", force: :cascade do |t|
    t.bigint "revaluation_act_id"
    t.bigint "product_id"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_revaluations_on_product_id"
    t.index ["revaluation_act_id"], name: "index_revaluations_on_revaluation_act_id"
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "service_job_id"
    t.bigint "client_id"
    t.string "phone"
    t.integer "value"
    t.text "content"
    t.string "token"
    t.datetime "sent_at"
    t.datetime "reviewed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "draft"
    t.index ["client_id"], name: "index_reviews_on_client_id"
    t.index ["service_job_id"], name: "index_reviews_on_service_job_id"
    t.index ["user_id"], name: "index_reviews_on_user_id"
  end

  create_table "salaries", force: :cascade do |t|
    t.bigint "user_id"
    t.integer "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "issued_at"
    t.boolean "is_prepayment"
    t.index ["is_prepayment"], name: "index_salaries_on_is_prepayment"
    t.index ["user_id"], name: "index_salaries_on_user_id"
  end

  create_table "sale_items", force: :cascade do |t|
    t.bigint "sale_id"
    t.bigint "item_id"
    t.decimal "price", precision: 8, scale: 2
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "discount", default: "0.0"
    t.integer "device_task_id"
    t.index ["device_task_id"], name: "index_sale_items_on_device_task_id"
    t.index ["item_id"], name: "index_sale_items_on_item_id"
    t.index ["sale_id"], name: "index_sale_items_on_sale_id"
  end

  create_table "sales", force: :cascade do |t|
    t.bigint "store_id"
    t.bigint "user_id"
    t.bigint "client_id"
    t.datetime "date"
    t.integer "status"
    t.boolean "is_return"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "cash_shift_id"
    t.index ["cash_shift_id"], name: "index_sales_on_cash_shift_id"
    t.index ["client_id"], name: "index_sales_on_client_id"
    t.index ["status"], name: "index_sales_on_status"
    t.index ["store_id"], name: "index_sales_on_store_id"
    t.index ["user_id"], name: "index_sales_on_user_id"
  end

  create_table "schedule_days", force: :cascade do |t|
    t.integer "user_id"
    t.integer "day"
    t.string "hours"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["day"], name: "index_schedule_days_on_day"
    t.index ["user_id"], name: "index_schedule_days_on_user_id"
  end

  create_table "service_feedbacks", force: :cascade do |t|
    t.bigint "service_job_id", null: false
    t.datetime "scheduled_on"
    t.integer "postpone_count", default: 0, null: false
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "log"
    t.index ["service_job_id"], name: "index_service_feedbacks_on_service_job_id"
  end

  create_table "service_free_jobs", force: :cascade do |t|
    t.bigint "performer_id", null: false
    t.bigint "client_id", null: false
    t.bigint "task_id", null: false
    t.text "comment"
    t.datetime "performed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "receiver_id"
    t.bigint "department_id", null: false
    t.index ["client_id"], name: "index_service_free_jobs_on_client_id"
    t.index ["department_id"], name: "index_service_free_jobs_on_department_id"
    t.index ["performer_id"], name: "index_service_free_jobs_on_performer_id"
    t.index ["receiver_id"], name: "index_service_free_jobs_on_receiver_id"
    t.index ["task_id"], name: "index_service_free_jobs_on_task_id"
  end

  create_table "service_free_tasks", force: :cascade do |t|
    t.string "name", null: false
    t.string "icon"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code"
  end

  create_table "service_job_subscriptions", id: false, force: :cascade do |t|
    t.bigint "service_job_id", null: false
    t.bigint "subscriber_id", null: false
    t.index ["service_job_id", "subscriber_id"], name: "index_service_job_subscriptions", unique: true
    t.index ["service_job_id"], name: "index_service_job_subscriptions_on_service_job_id"
    t.index ["subscriber_id"], name: "index_service_job_subscriptions_on_subscriber_id"
  end

  create_table "service_job_templates", force: :cascade do |t|
    t.string "field_name"
    t.string "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["field_name"], name: "index_service_job_templates_on_field_name"
  end

  create_table "service_job_viewings", force: :cascade do |t|
    t.bigint "service_job_id", null: false
    t.bigint "user_id", null: false
    t.datetime "time", null: false
    t.string "ip", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_job_id"], name: "index_service_job_viewings_on_service_job_id"
    t.index ["time"], name: "index_service_job_viewings_on_time"
    t.index ["user_id"], name: "index_service_job_viewings_on_user_id"
  end

  create_table "service_jobs", force: :cascade do |t|
    t.bigint "device_type_id"
    t.string "ticket_number"
    t.bigint "client_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "done_at"
    t.string "serial_number"
    t.integer "location_id"
    t.integer "user_id"
    t.string "imei"
    t.boolean "replaced", default: false
    t.string "security_code"
    t.string "status"
    t.boolean "notify_client", default: false
    t.boolean "client_notified"
    t.datetime "return_at"
    t.integer "item_id"
    t.string "app_store_pass"
    t.text "tech_notice"
    t.integer "sale_id"
    t.integer "case_color_id"
    t.string "contact_phone"
    t.integer "department_id"
    t.boolean "is_tray_present"
    t.integer "carrier_id"
    t.integer "keeper_id"
    t.string "data_storages"
    t.string "email"
    t.string "client_address"
    t.text "claimed_defect"
    t.text "device_condition"
    t.text "client_comment"
    t.string "estimated_cost_of_repair"
    t.string "type_of_work"
    t.bigint "initial_department_id"
    t.string "trademark"
    t.string "completeness"
    t.string "device_group"
    t.index ["carrier_id"], name: "index_service_jobs_on_carrier_id"
    t.index ["case_color_id"], name: "index_service_jobs_on_case_color_id"
    t.index ["client_id"], name: "index_service_jobs_on_client_id"
    t.index ["department_id"], name: "index_service_jobs_on_department_id"
    t.index ["device_type_id"], name: "index_service_jobs_on_device_type_id"
    t.index ["done_at"], name: "index_service_jobs_on_done_at"
    t.index ["imei"], name: "index_service_jobs_on_imei"
    t.index ["initial_department_id"], name: "index_service_jobs_on_initial_department_id"
    t.index ["item_id"], name: "index_service_jobs_on_item_id"
    t.index ["location_id"], name: "index_service_jobs_on_location_id"
    t.index ["sale_id"], name: "index_service_jobs_on_sale_id"
    t.index ["status"], name: "index_service_jobs_on_status"
    t.index ["ticket_number"], name: "index_service_jobs_on_ticket_number"
    t.index ["user_id"], name: "index_service_jobs_on_user_id"
  end

  create_table "service_repair_returns", force: :cascade do |t|
    t.bigint "service_job_id", null: false
    t.bigint "performer_id", null: false
    t.datetime "performed_at", null: false
    t.index ["performer_id"], name: "index_service_repair_returns_on_performer_id"
    t.index ["service_job_id"], name: "index_service_repair_returns_on_service_job_id"
  end

  create_table "service_sms_notifications", force: :cascade do |t|
    t.bigint "sender_id", null: false
    t.datetime "sent_at", null: false
    t.text "message", null: false
    t.string "phone_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sender_id"], name: "index_service_sms_notifications_on_sender_id"
  end

  create_table "settings", force: :cascade do |t|
    t.string "name"
    t.string "presentation"
    t.text "value"
    t.string "value_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.index ["name"], name: "index_settings_on_name"
  end

  create_table "spare_part_defects", force: :cascade do |t|
    t.bigint "item_id"
    t.bigint "contractor_id"
    t.integer "qty", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "repair_part_id"
    t.boolean "is_warranty", default: false, null: false
    t.index ["contractor_id"], name: "index_spare_part_defects_on_contractor_id"
    t.index ["item_id"], name: "index_spare_part_defects_on_item_id"
    t.index ["repair_part_id"], name: "index_spare_part_defects_on_repair_part_id"
  end

  create_table "spare_parts", force: :cascade do |t|
    t.bigint "repair_service_id"
    t.bigint "product_id"
    t.integer "quantity"
    t.integer "warranty_term"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_spare_parts_on_product_id"
    t.index ["repair_service_id"], name: "index_spare_parts_on_repair_service_id"
  end

  create_table "stolen_phones", force: :cascade do |t|
    t.string "imei"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "serial_number"
    t.integer "client_id"
    t.text "client_comment"
    t.bigint "item_id"
    t.index ["client_id"], name: "index_stolen_phones_on_client_id"
    t.index ["imei"], name: "index_stolen_phones_on_imei"
    t.index ["item_id"], name: "index_stolen_phones_on_item_id"
    t.index ["serial_number"], name: "index_stolen_phones_on_serial_number"
  end

  create_table "store_items", force: :cascade do |t|
    t.bigint "item_id"
    t.bigint "store_id"
    t.integer "quantity", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_store_items_on_item_id"
    t.index ["store_id"], name: "index_store_items_on_store_id"
  end

  create_table "store_products", force: :cascade do |t|
    t.bigint "store_id"
    t.bigint "product_id"
    t.integer "warning_quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "store_id"], name: "index_store_products_on_product_id_and_store_id"
    t.index ["product_id"], name: "index_store_products_on_product_id"
    t.index ["store_id"], name: "index_store_products_on_store_id"
  end

  create_table "stores", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code"
    t.string "kind"
    t.integer "department_id"
    t.boolean "hidden"
    t.index ["code"], name: "index_stores_on_code"
    t.index ["department_id"], name: "index_stores_on_department_id"
  end

  create_table "substitute_phones", force: :cascade do |t|
    t.bigint "item_id"
    t.text "condition", null: false
    t.bigint "service_job_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "department_id"
    t.boolean "archived"
    t.index ["department_id"], name: "index_substitute_phones_on_department_id"
    t.index ["item_id"], name: "index_substitute_phones_on_item_id"
    t.index ["service_job_id"], name: "index_substitute_phones_on_service_job_id", unique: true
  end

  create_table "supplies", force: :cascade do |t|
    t.bigint "supply_report_id"
    t.bigint "supply_category_id"
    t.string "name"
    t.integer "quantity"
    t.decimal "cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["supply_category_id"], name: "index_supplies_on_supply_category_id"
    t.index ["supply_report_id"], name: "index_supplies_on_supply_report_id"
  end

  create_table "supply_categories", force: :cascade do |t|
    t.string "name"
    t.string "ancestry"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestry"], name: "index_supply_categories_on_ancestry"
  end

  create_table "supply_reports", force: :cascade do |t|
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.index ["department_id"], name: "index_supply_reports_on_department_id"
  end

  create_table "supply_requests", force: :cascade do |t|
    t.bigint "user_id"
    t.string "status"
    t.string "object"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.index ["department_id"], name: "index_supply_requests_on_department_id"
    t.index ["status"], name: "index_supply_requests_on_status"
    t.index ["user_id"], name: "index_supply_requests_on_user_id"
  end

  create_table "task_templates", force: :cascade do |t|
    t.text "content", null: false
    t.string "icon"
    t.string "ancestry"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestry"], name: "index_task_templates_on_ancestry"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "name"
    t.integer "duration"
    t.decimal "cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "priority", default: 0
    t.string "role"
    t.integer "product_id"
    t.boolean "hidden", default: false
    t.string "code"
    t.string "location_code"
    t.index ["name"], name: "index_tasks_on_name"
    t.index ["product_id"], name: "index_tasks_on_product_id"
    t.index ["role"], name: "index_tasks_on_role"
  end

  create_table "timesheet_days", force: :cascade do |t|
    t.date "date"
    t.bigint "user_id"
    t.string "status"
    t.integer "work_mins"
    t.time "time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_timesheet_days_on_date"
    t.index ["status"], name: "index_timesheet_days_on_status"
    t.index ["user_id"], name: "index_timesheet_days_on_user_id"
  end

  create_table "top_salables", force: :cascade do |t|
    t.bigint "product_id"
    t.string "name"
    t.string "ancestry"
    t.integer "position"
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestry"], name: "index_top_salables_on_ancestry"
    t.index ["product_id"], name: "index_top_salables_on_product_id"
  end

  create_table "trade_in_devices", force: :cascade do |t|
    t.integer "number"
    t.datetime "received_at", null: false
    t.bigint "item_id", null: false
    t.bigint "receiver_id"
    t.integer "appraised_value", null: false
    t.string "appraiser", null: false
    t.string "bought_device", null: false
    t.string "client_name"
    t.string "client_phone"
    t.string "check_icloud", null: false
    t.integer "replacement_status"
    t.boolean "archived", default: false, null: false
    t.text "archiving_comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "condition"
    t.text "equipment"
    t.date "apple_guarantee"
    t.bigint "department_id", null: false
    t.boolean "confirmed", default: false, null: false
    t.boolean "extended_guarantee"
    t.integer "sale_amount"
    t.bigint "client_id"
    t.index ["client_id"], name: "index_trade_in_devices_on_client_id"
    t.index ["department_id"], name: "index_trade_in_devices_on_department_id"
    t.index ["item_id"], name: "index_trade_in_devices_on_item_id"
    t.index ["receiver_id"], name: "index_trade_in_devices_on_receiver_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "username", default: "", null: false
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email", default: ""
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "authentication_token"
    t.integer "location_id"
    t.string "photo"
    t.string "surname"
    t.string "name"
    t.string "patronymic"
    t.date "birthday"
    t.date "hiring_date"
    t.date "salary_date"
    t.string "prepayment"
    t.text "wish"
    t.string "card_number"
    t.string "color"
    t.integer "abilities_mask"
    t.boolean "schedule"
    t.integer "position"
    t.boolean "is_fired"
    t.string "job_title"
    t.integer "store_id"
    t.integer "department_id"
    t.integer "session_duration"
    t.string "phone_number"
    t.boolean "department_autochangeable", default: true, null: false
    t.boolean "can_help_in_repair", default: false
    t.string "uniform_sex"
    t.string "uniform_size"
    t.integer "activities_mask"
    t.string "wishlist", default: [], array: true
    t.text "hobby"
    t.boolean "can_help_in_mac_service", default: false
    t.string "work_phone"
    t.index ["authentication_token"], name: "index_users_on_authentication_token", unique: true
    t.index ["card_number"], name: "index_users_on_card_number"
    t.index ["department_id"], name: "index_users_on_department_id"
    t.index ["email"], name: "index_users_on_email"
    t.index ["is_fired"], name: "index_users_on_is_fired"
    t.index ["job_title"], name: "index_users_on_job_title"
    t.index ["location_id"], name: "index_users_on_location_id"
    t.index ["name"], name: "index_users_on_name"
    t.index ["patronymic"], name: "index_users_on_patronymic"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["schedule"], name: "index_users_on_schedule"
    t.index ["store_id"], name: "index_users_on_store_id"
    t.index ["surname"], name: "index_users_on_surname"
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  create_table "wiki_page_attachments", force: :cascade do |t|
    t.integer "page_id", null: false
    t.string "wiki_page_attachment_file_name"
    t.string "wiki_page_attachment_content_type"
    t.integer "wiki_page_attachment_file_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "wiki_page_versions", force: :cascade do |t|
    t.integer "page_id", null: false
    t.integer "updator_id"
    t.integer "number"
    t.string "comment"
    t.string "path"
    t.string "title"
    t.text "content"
    t.datetime "updated_at"
    t.index ["page_id"], name: "index_wiki_page_versions_on_page_id"
    t.index ["updator_id"], name: "index_wiki_page_versions_on_updator_id"
  end

  create_table "wiki_pages", force: :cascade do |t|
    t.integer "creator_id"
    t.integer "updator_id"
    t.string "path"
    t.string "title"
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_wiki_pages_on_creator_id"
    t.index ["path"], name: "index_wiki_pages_on_path", unique: true
  end

  add_foreign_key "departments", "brands"
  add_foreign_key "departments", "cities"
  add_foreign_key "faults", "fault_kinds", column: "kind_id"
  add_foreign_key "faults", "users", column: "causer_id"
  add_foreign_key "lost_devices", "service_jobs"
  add_foreign_key "messages", "departments"
  add_foreign_key "option_values", "option_types"
  add_foreign_key "order_notes", "orders"
  add_foreign_key "order_notes", "users", column: "author_id"
  add_foreign_key "phone_substitutions", "service_jobs"
  add_foreign_key "phone_substitutions", "substitute_phones"
  add_foreign_key "phone_substitutions", "users", column: "issuer_id"
  add_foreign_key "phone_substitutions", "users", column: "receiver_id"
  add_foreign_key "product_groups_option_values", "option_values"
  add_foreign_key "product_groups_option_values", "product_groups"
  add_foreign_key "product_options", "option_values"
  add_foreign_key "product_options", "products"
  add_foreign_key "quick_orders", "clients"
  add_foreign_key "repair_prices", "departments"
  add_foreign_key "repair_prices", "repair_services"
  add_foreign_key "repair_tasks", "users", column: "repairer_id"
  add_foreign_key "reviews", "clients"
  add_foreign_key "reviews", "service_jobs"
  add_foreign_key "reviews", "users"
  add_foreign_key "service_feedbacks", "service_jobs"
  add_foreign_key "service_free_jobs", "clients"
  add_foreign_key "service_free_jobs", "departments"
  add_foreign_key "service_free_jobs", "service_free_tasks", column: "task_id"
  add_foreign_key "service_free_jobs", "users", column: "performer_id"
  add_foreign_key "service_free_jobs", "users", column: "receiver_id"
  add_foreign_key "service_job_viewings", "service_jobs"
  add_foreign_key "service_job_viewings", "users"
  add_foreign_key "service_jobs", "departments", column: "initial_department_id"
  add_foreign_key "service_repair_returns", "service_jobs"
  add_foreign_key "service_repair_returns", "users", column: "performer_id"
  add_foreign_key "service_sms_notifications", "users", column: "sender_id"
  add_foreign_key "spare_part_defects", "contractors"
  add_foreign_key "spare_part_defects", "items"
  add_foreign_key "spare_part_defects", "repair_parts"
  add_foreign_key "stolen_phones", "items"
  add_foreign_key "substitute_phones", "departments"
  add_foreign_key "substitute_phones", "items"
  add_foreign_key "substitute_phones", "service_jobs"
  add_foreign_key "trade_in_devices", "clients"
  add_foreign_key "trade_in_devices", "departments"
  add_foreign_key "trade_in_devices", "items"
  add_foreign_key "trade_in_devices", "users", column: "receiver_id"
end
