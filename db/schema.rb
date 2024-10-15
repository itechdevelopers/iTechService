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

ActiveRecord::Schema.define(version: 20241011095809) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "citext"
  enable_extension "hstore"
  enable_extension "pg_stat_statements"

  create_table "abilities", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_abilities_on_name", unique: true
  end

  create_table "announcements", id: :serial, force: :cascade do |t|
    t.string "content", limit: 255
    t.string "kind", limit: 255, null: false
    t.integer "user_id"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.index ["department_id"], name: "index_announcements_on_department_id"
    t.index ["kind"], name: "index_announcements_on_kind"
    t.index ["user_id"], name: "index_announcements_on_user_id"
  end

  create_table "announcements_users", id: :serial, force: :cascade do |t|
    t.integer "announcement_id"
    t.integer "user_id"
  end

  create_table "audits", force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.jsonb "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at"
    t.jsonb "metadata", default: {}, null: false
    t.index "((metadata ->> 'audit_type'::text))", name: "index_audits_on_metadata_audit_type"
    t.index "((metadata ->> 'department_id'::text))", name: "index_audits_on_metadata_department_id"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["metadata"], name: "index_audits_on_metadata", using: :gin
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "banks", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "batches", id: :serial, force: :cascade do |t|
    t.integer "purchase_id"
    t.integer "item_id"
    t.decimal "price", precision: 8, scale: 2
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_batches_on_item_id"
    t.index ["purchase_id"], name: "index_batches_on_purchase_id"
  end

  create_table "bonus_types", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "bonuses", id: :serial, force: :cascade do |t|
    t.integer "bonus_type_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bonus_type_id"], name: "index_bonuses_on_bonus_type_id"
  end

  create_table "brands", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.string "logo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "carriers", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "case_colors", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "color", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cash_drawers", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.integer "department_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_cash_drawers_on_department_id"
  end

  create_table "cash_operations", id: :serial, force: :cascade do |t|
    t.integer "cash_shift_id"
    t.integer "user_id"
    t.boolean "is_out", default: false
    t.decimal "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "comment"
    t.index ["cash_shift_id"], name: "index_cash_operations_on_cash_shift_id"
    t.index ["user_id"], name: "index_cash_operations_on_user_id"
  end

  create_table "cash_shifts", id: :serial, force: :cascade do |t|
    t.boolean "is_closed", default: false
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "closed_at"
    t.integer "cash_drawer_id"
    t.index ["cash_drawer_id"], name: "index_cash_shifts_on_cash_drawer_id"
    t.index ["user_id"], name: "index_cash_shifts_on_user_id"
  end

  create_table "cities", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "time_zone"
  end

  create_table "ckeditor_assets", id: :serial, force: :cascade do |t|
    t.string "data_file_name", limit: 255, null: false
    t.string "data_content_type", limit: 255
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

  create_table "client_categories", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "color", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "client_characteristics", id: :serial, force: :cascade do |t|
    t.integer "client_category_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_category_id"], name: "index_client_characteristics_on_client_category_id"
  end

  create_table "clients", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "phone_number", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "card_number", limit: 255
    t.string "full_phone_number", limit: 255
    t.string "surname", limit: 255
    t.string "patronymic", limit: 255
    t.date "birthday"
    t.string "email", limit: 255
    t.text "admin_info"
    t.string "contact_phone", limit: 255
    t.integer "client_characteristic_id"
    t.integer "category"
    t.integer "department_id"
    t.boolean "disable_deadline_notifications", default: false
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

  create_table "comments", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "commentable_id", null: false
    t.string "commentable_type", limit: 255, null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commentable_id", "commentable_type"], name: "index_comments_on_commentable_id_and_commentable_type"
    t.index ["commentable_id"], name: "index_comments_on_commentable_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "contractors", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "data_migrations", id: false, force: :cascade do |t|
    t.string "version", null: false
    t.index ["version"], name: "unique_data_migrations", unique: true
  end

  create_table "deduction_acts", id: :serial, force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.datetime "date"
    t.integer "store_id"
    t.integer "user_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["store_id"], name: "index_deduction_acts_on_store_id"
    t.index ["user_id"], name: "index_deduction_acts_on_user_id"
  end

  create_table "deduction_items", id: :serial, force: :cascade do |t|
    t.integer "item_id", null: false
    t.integer "deduction_act_id"
    t.integer "quantity", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deduction_act_id"], name: "index_deduction_items_on_deduction_act_id"
    t.index ["item_id"], name: "index_deduction_items_on_item_id"
  end

  create_table "delayed_jobs", id: :serial, force: :cascade do |t|
    t.integer "priority", default: 0
    t.integer "attempts", default: 0
    t.text "handler"
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by", limit: 255
    t.string "queue", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "departments", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "code", limit: 255
    t.integer "role"
    t.string "url", limit: 255
    t.string "address", limit: 255
    t.string "contact_phone", limit: 255
    t.text "schedule"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "printer"
    t.string "ip_network"
    t.integer "city_id", null: false
    t.integer "brand_id"
    t.string "short_name"
    t.boolean "archive", default: false
    t.index ["brand_id"], name: "index_departments_on_brand_id"
    t.index ["city_id"], name: "index_departments_on_city_id"
    t.index ["code"], name: "index_departments_on_code"
    t.index ["role"], name: "index_departments_on_role"
  end

  create_table "device_notes", id: :serial, force: :cascade do |t|
    t.integer "service_job_id", null: false
    t.integer "user_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_job_id"], name: "index_device_notes_on_service_job_id"
    t.index ["user_id"], name: "index_device_notes_on_user_id"
  end

  create_table "device_tasks", id: :serial, force: :cascade do |t|
    t.integer "service_job_id"
    t.integer "task_id"
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

  create_table "device_types", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "ancestry", limit: 255
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

  create_table "discounts", id: :serial, force: :cascade do |t|
    t.integer "value"
    t.integer "limit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["limit"], name: "index_discounts_on_limit"
  end

  create_table "dismissal_reasons", force: :cascade do |t|
    t.string "name"
  end

  create_table "duty_days", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.date "day"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "kind", limit: 255
    t.index ["day"], name: "index_duty_days_on_day"
    t.index ["kind"], name: "index_duty_days_on_kind"
    t.index ["user_id"], name: "index_duty_days_on_user_id"
  end

  create_table "electronic_queues", force: :cascade do |t|
    t.string "queue_name"
    t.bigint "department_id", null: false
    t.integer "windows_count"
    t.string "printer_address"
    t.string "ipad_link"
    t.string "tv_link"
    t.boolean "enabled"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "header_boldness", default: 600
    t.integer "header_font_size", default: 24
    t.integer "annotation_boldness", default: 400
    t.integer "annotation_font_size", default: 18
    t.string "check_info", default: ""
    t.string "background_color"
    t.string "queue_item_color"
    t.string "back_button_color"
    t.string "automatic_completion"
    t.index ["department_id"], name: "index_electronic_queues_on_department_id"
    t.index ["ipad_link"], name: "index_electronic_queues_on_ipad_link", unique: true
    t.index ["tv_link"], name: "index_electronic_queues_on_tv_link", unique: true
  end

  create_table "elqueue_ticket_movements", force: :cascade do |t|
    t.string "type"
    t.bigint "waiting_client_id", null: false
    t.integer "old_position"
    t.integer "new_position"
    t.jsonb "queue_state", default: {}, null: false
    t.bigint "user_id"
    t.integer "priority"
    t.bigint "elqueue_window_id"
    t.bigint "electronic_queue_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_elqueue_ticket_movements_on_created_at"
    t.index ["electronic_queue_id"], name: "index_elqueue_ticket_movements_on_electronic_queue_id"
    t.index ["elqueue_window_id"], name: "index_elqueue_ticket_movements_on_elqueue_window_id"
    t.index ["user_id"], name: "index_elqueue_ticket_movements_on_user_id"
    t.index ["waiting_client_id"], name: "index_elqueue_ticket_movements_on_waiting_client_id"
  end

  create_table "elqueue_windows", force: :cascade do |t|
    t.integer "window_number", null: false
    t.bigint "electronic_queue_id", null: false
    t.boolean "is_active", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["electronic_queue_id"], name: "index_elqueue_windows_on_electronic_queue_id"
  end

  create_table "fault_kinds", id: :serial, force: :cascade do |t|
    t.string "name"
    t.string "icon"
    t.boolean "is_permanent", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.boolean "financial", default: false, null: false
    t.string "penalties"
  end

  create_table "faults", id: :serial, force: :cascade do |t|
    t.integer "causer_id", null: false
    t.integer "kind_id", null: false
    t.date "date"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "penalty"
    t.boolean "expired", default: false, null: false
    t.bigint "issued_by_id"
    t.index ["causer_id"], name: "index_faults_on_causer_id"
    t.index ["issued_by_id"], name: "index_faults_on_issued_by_id"
    t.index ["kind_id"], name: "index_faults_on_kind_id"
  end

  create_table "favorite_links", id: :serial, force: :cascade do |t|
    t.integer "owner_id", null: false
    t.string "name"
    t.string "url", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_favorite_links_on_owner_id"
  end

  create_table "feature_types", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "kind", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_feature_types_on_code"
  end

  create_table "feature_types_product_categories", id: :serial, force: :cascade do |t|
    t.integer "product_category_id"
    t.integer "feature_type_id"
  end

  create_table "features", id: :serial, force: :cascade do |t|
    t.integer "feature_type_id"
    t.integer "item_id"
    t.string "value", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_type_id"], name: "index_features_on_feature_type_id"
    t.index ["item_id"], name: "index_features_on_item_id"
    t.index ["value"], name: "index_features_on_value"
  end

  create_table "features_items", id: :serial, force: :cascade do |t|
    t.integer "feature_id"
    t.integer "item_id"
  end

  create_table "gift_certificates", id: :serial, force: :cascade do |t|
    t.string "number", limit: 255
    t.integer "nominal"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "consumed"
    t.integer "department_id"
    t.index ["department_id"], name: "index_gift_certificates_on_department_id"
    t.index ["number"], name: "index_gift_certificates_on_number"
  end

  create_table "history_records", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "object_id"
    t.string "object_type", limit: 255
    t.string "column_name", limit: 255
    t.string "column_type", limit: 255
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "old_value"
    t.text "new_value"
    t.index ["column_name"], name: "index_history_records_on_column_name"
    t.index ["object_id", "object_type"], name: "index_history_records_on_object_id_and_object_type"
    t.index ["user_id"], name: "index_history_records_on_user_id"
  end

  create_table "imported_sales", id: :serial, force: :cascade do |t|
    t.integer "device_type_id"
    t.string "imei", limit: 255
    t.string "serial_number", limit: 255
    t.datetime "sold_at"
    t.string "quantity", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["device_type_id"], name: "index_imported_sales_on_device_type_id"
    t.index ["imei"], name: "index_imported_sales_on_imei"
    t.index ["quantity"], name: "index_imported_sales_on_quantity"
    t.index ["serial_number"], name: "index_imported_sales_on_serial_number"
    t.index ["sold_at"], name: "index_imported_sales_on_sold_at"
  end

  create_table "infos", id: :serial, force: :cascade do |t|
    t.string "title", limit: 255, null: false
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

  create_table "installment_plans", id: :serial, force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "object", limit: 255
    t.integer "cost"
    t.date "issued_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_closed", default: false
    t.index ["is_closed"], name: "index_installment_plans_on_is_closed"
    t.index ["user_id"], name: "index_installment_plans_on_user_id"
  end

  create_table "installments", id: :serial, force: :cascade do |t|
    t.integer "installment_plan_id"
    t.integer "value"
    t.date "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["installment_plan_id"], name: "index_installments_on_installment_plan_id"
  end

  create_table "items", id: :serial, force: :cascade do |t|
    t.integer "product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "barcode_num", limit: 255
    t.index ["barcode_num"], name: "index_items_on_barcode_num"
    t.index ["product_id"], name: "index_items_on_product_id"
  end

  create_table "kanban_boards", force: :cascade do |t|
    t.string "name", null: false
    t.string "background"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "allowed_user_ids", default: [], array: true
    t.string "open_background_color"
    t.string "card_font_color"
    t.integer "card_font_size"
    t.integer "open_card_font_size"
    t.index ["allowed_user_ids"], name: "index_kanban_boards_on_allowed_user_ids"
  end

  create_table "kanban_boards_users", id: false, force: :cascade do |t|
    t.bigint "kanban_board_id", null: false
    t.bigint "user_id", null: false
    t.index ["kanban_board_id", "user_id"], name: "index_kanban_boards_users_on_kanban_board_id_and_user_id"
  end

  create_table "kanban_cards", force: :cascade do |t|
    t.text "content"
    t.bigint "author_id", null: false
    t.bigint "column_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "photos", default: [], array: true
    t.date "deadline"
    t.string "name"
    t.index ["column_id"], name: "index_kanban_cards_on_column_id"
  end

  create_table "kanban_cards_users", id: false, force: :cascade do |t|
    t.bigint "kanban_card_id", null: false
    t.bigint "user_id", null: false
    t.index ["kanban_card_id", "user_id"], name: "index_kanban_cards_users_on_kanban_card_id_and_user_id"
  end

  create_table "kanban_columns", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "board_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["board_id"], name: "index_kanban_columns_on_board_id"
  end

  create_table "karma_groups", id: :serial, force: :cascade do |t|
    t.integer "bonus_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bonus_id"], name: "index_karma_groups_on_bonus_id"
  end

  create_table "karmas", id: :serial, force: :cascade do |t|
    t.boolean "good"
    t.text "comment"
    t.integer "user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "karma_group_id"
    t.index ["karma_group_id"], name: "index_karmas_on_karma_group_id"
    t.index ["user_id"], name: "index_karmas_on_user_id"
  end

  create_table "locations", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "ancestry", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "schedule"
    t.integer "position", default: 0
    t.string "code", limit: 255
    t.integer "department_id"
    t.boolean "hidden", default: false
    t.integer "storage_term"
    t.index ["ancestry"], name: "index_locations_on_ancestry"
    t.index ["code"], name: "index_locations_on_code"
    t.index ["department_id"], name: "index_locations_on_department_id"
    t.index ["name"], name: "index_locations_on_name"
    t.index ["schedule"], name: "index_locations_on_schedule"
  end

  create_table "lost_devices", id: :serial, force: :cascade do |t|
    t.integer "service_job_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_job_id"], name: "index_lost_devices_on_service_job_id", unique: true
  end

  create_table "media_orders", id: :serial, force: :cascade do |t|
    t.datetime "time"
    t.string "name", limit: 255
    t.string "phone", limit: 255
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "messages", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "content", limit: 255
    t.integer "recipient_id"
    t.string "recipient_type", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id", null: false
    t.index ["department_id"], name: "index_messages_on_department_id"
    t.index ["recipient_id"], name: "index_messages_on_recipient_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "movement_acts", id: :serial, force: :cascade do |t|
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

  create_table "movement_items", id: :serial, force: :cascade do |t|
    t.integer "movement_act_id"
    t.integer "item_id"
    t.integer "quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_movement_items_on_item_id"
    t.index ["movement_act_id"], name: "index_movement_items_on_movement_act_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.string "referenceable_type"
    t.bigint "referenceable_id"
    t.bigint "user_id", null: false
    t.string "url"
    t.datetime "closed_at"
    t.text "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["referenceable_type", "referenceable_id"], name: "index_notifications_on_referenceable_type_and_referenceable_id"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "option_types", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.string "code"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_option_types_on_code"
    t.index ["name"], name: "index_option_types_on_name"
  end

  create_table "option_values", id: :serial, force: :cascade do |t|
    t.integer "option_type_id", null: false
    t.string "name", null: false
    t.string "code"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_option_values_on_code"
    t.index ["name"], name: "index_option_values_on_name"
    t.index ["option_type_id"], name: "index_option_values_on_option_type_id"
  end

  create_table "order_notes", id: :serial, force: :cascade do |t|
    t.integer "order_id", null: false
    t.integer "author_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_order_notes_on_author_id"
    t.index ["order_id"], name: "index_order_notes_on_order_id"
  end

  create_table "orders", id: :serial, force: :cascade do |t|
    t.string "number", limit: 255
    t.integer "customer_id"
    t.string "customer_type", limit: 255
    t.string "object_kind", limit: 255
    t.string "object", limit: 255
    t.date "desired_date"
    t.string "status", limit: 255
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
    t.index ["department_id"], name: "index_orders_on_department_id"
    t.index ["object_kind"], name: "index_orders_on_object_kind"
    t.index ["priority"], name: "index_orders_on_priority"
    t.index ["status"], name: "index_orders_on_status"
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "payment_types", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "kind", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_payment_types_on_kind"
  end

  create_table "payments", id: :serial, force: :cascade do |t|
    t.string "kind", limit: 255
    t.decimal "value"
    t.integer "sale_id"
    t.integer "bank_id"
    t.integer "gift_certificate_id"
    t.string "device_name", limit: 255
    t.string "device_number", limit: 255
    t.string "client_info", limit: 255
    t.string "appraiser", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bank_id"], name: "index_payments_on_bank_id"
    t.index ["gift_certificate_id"], name: "index_payments_on_gift_certificate_id"
    t.index ["kind"], name: "index_payments_on_kind"
    t.index ["sale_id"], name: "index_payments_on_sale_id"
  end

  create_table "phone_substitutions", id: :serial, force: :cascade do |t|
    t.integer "substitute_phone_id", null: false
    t.integer "service_job_id", null: false
    t.integer "issuer_id", null: false
    t.datetime "issued_at", null: false
    t.integer "receiver_id"
    t.boolean "condition_match"
    t.datetime "withdrawn_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["issuer_id"], name: "index_phone_substitutions_on_issuer_id"
    t.index ["receiver_id"], name: "index_phone_substitutions_on_receiver_id"
    t.index ["service_job_id"], name: "index_phone_substitutions_on_service_job_id"
    t.index ["substitute_phone_id"], name: "index_phone_substitutions_on_substitute_phone_id"
  end

  create_table "photo_containers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reception_photos", default: [], array: true
    t.string "in_operation_photos", default: [], array: true
    t.string "completed_photos", default: [], array: true
    t.string "reception_photos_meta_data", default: [], array: true
    t.string "in_operation_photos_meta_data", default: [], array: true
    t.string "completed_photos_meta_data", default: [], array: true
  end

  create_table "price_types", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.integer "kind"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["kind"], name: "index_price_types_on_kind"
  end

  create_table "price_types_stores", id: :serial, force: :cascade do |t|
    t.integer "price_type_id"
    t.integer "store_id"
    t.index ["price_type_id"], name: "index_price_types_stores_on_price_type_id"
    t.index ["store_id"], name: "index_price_types_stores_on_store_id"
  end

  create_table "prices", id: :serial, force: :cascade do |t|
    t.string "file", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.index ["department_id"], name: "index_prices_on_department_id"
  end

  create_table "product_categories", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.boolean "feature_accounting", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "warranty_term"
    t.string "kind", limit: 255
    t.boolean "request_price"
    t.index ["kind"], name: "index_product_categories_on_kind"
  end

  create_table "product_groups", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "ancestry", limit: 255
    t.integer "product_category_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "ancestry_depth", default: 0
    t.string "code", limit: 255
    t.integer "position", default: 0, null: false
    t.integer "warranty_term", default: 0, null: false
    t.boolean "available_for_trade_in"
    t.index ["ancestry"], name: "index_product_groups_on_ancestry"
    t.index ["code"], name: "index_product_groups_on_code"
    t.index ["product_category_id"], name: "index_product_groups_on_product_category_id"
  end

  create_table "product_groups_option_values", id: false, force: :cascade do |t|
    t.integer "product_group_id"
    t.integer "option_value_id"
    t.index ["option_value_id"], name: "index_product_groups_option_values_on_option_value_id"
    t.index ["product_group_id"], name: "index_product_groups_option_values_on_product_group_id"
  end

  create_table "product_options", id: false, force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "option_value_id", null: false
    t.index ["option_value_id"], name: "index_product_options_on_option_value_id"
    t.index ["product_id"], name: "index_product_options_on_product_id"
  end

  create_table "product_prices", id: :serial, force: :cascade do |t|
    t.integer "product_id"
    t.integer "price_type_id"
    t.datetime "date"
    t.decimal "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.index ["department_id"], name: "index_product_prices_on_department_id"
    t.index ["price_type_id"], name: "index_product_prices_on_price_type_id"
    t.index ["product_id"], name: "index_product_prices_on_product_id"
  end

  create_table "product_relations", id: :serial, force: :cascade do |t|
    t.integer "parent_id"
    t.string "parent_type", limit: 255
    t.integer "relatable_id"
    t.string "relatable_type", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_type", "parent_id"], name: "index_product_relations_on_parent_type_and_parent_id"
    t.index ["relatable_type", "relatable_id"], name: "index_product_relations_on_relatable_type_and_relatable_id"
  end

  create_table "products", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "code", limit: 255
    t.integer "product_group_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "warranty_term"
    t.integer "device_type_id"
    t.integer "quantity_threshold"
    t.text "comment"
    t.integer "product_category_id"
    t.string "barcode_num"
    t.string "article"
    t.index ["article"], name: "index_products_on_article", unique: true
    t.index ["barcode_num"], name: "index_products_on_barcode_num"
    t.index ["code"], name: "index_products_on_code"
    t.index ["device_type_id"], name: "index_products_on_device_type_id"
    t.index ["name"], name: "index_products_on_name"
    t.index ["product_category_id"], name: "index_products_on_product_category_id"
    t.index ["product_group_id"], name: "index_products_on_product_group_id"
  end

  create_table "purchases", id: :serial, force: :cascade do |t|
    t.integer "contractor_id"
    t.integer "store_id"
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

  create_table "queue_items", force: :cascade do |t|
    t.string "title"
    t.text "annotation"
    t.boolean "phone_input"
    t.string "windows"
    t.integer "task_duration"
    t.integer "max_wait_time"
    t.text "additional_info"
    t.string "ticket_abbreviation"
    t.bigint "electronic_queue_id", null: false
    t.integer "position", default: 0, null: false
    t.string "ancestry"
    t.integer "ancestry_depth", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "priority", default: 0
    t.integer "last_ticket_number"
    t.boolean "archived", default: false
    t.index ["electronic_queue_id"], name: "index_queue_items_on_electronic_queue_id"
  end

  create_table "quick_orders", id: :serial, force: :cascade do |t|
    t.integer "number"
    t.boolean "is_done"
    t.integer "user_id"
    t.string "client_name", limit: 255
    t.string "contact_phone", limit: 255
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "security_code", limit: 255
    t.integer "department_id"
    t.string "device_kind", limit: 255
    t.integer "client_id"
    t.string "apple_id_password"
    t.index ["client_id"], name: "index_quick_orders_on_client_id"
    t.index ["client_name"], name: "index_quick_orders_on_client_name"
    t.index ["contact_phone"], name: "index_quick_orders_on_contact_phone"
    t.index ["department_id"], name: "index_quick_orders_on_department_id"
    t.index ["number"], name: "index_quick_orders_on_number"
    t.index ["user_id"], name: "index_quick_orders_on_user_id"
  end

  create_table "quick_orders_quick_tasks", id: false, force: :cascade do |t|
    t.integer "quick_order_id"
    t.integer "quick_task_id"
    t.index ["quick_order_id", "quick_task_id"], name: "index_quick_orders_tasks"
  end

  create_table "quick_tasks", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "record_edits", force: :cascade do |t|
    t.bigint "user_id"
    t.string "editable_type"
    t.bigint "editable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "updated_text"
    t.index ["editable_type", "editable_id"], name: "index_record_edits_on_editable_type_and_editable_id"
    t.index ["user_id"], name: "index_record_edits_on_user_id"
  end

  create_table "repair_groups", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "ancestry", limit: 255
    t.integer "ancestry_depth", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestry"], name: "index_repair_groups_on_ancestry"
  end

  create_table "repair_parts", id: :serial, force: :cascade do |t|
    t.integer "repair_task_id"
    t.integer "item_id"
    t.integer "quantity"
    t.integer "warranty_term"
    t.integer "defect_qty"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_repair_parts_on_item_id"
    t.index ["repair_task_id"], name: "index_repair_parts_on_repair_task_id"
  end

  create_table "repair_prices", id: :serial, force: :cascade do |t|
    t.integer "repair_service_id"
    t.integer "department_id"
    t.decimal "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_repair_prices_on_department_id"
    t.index ["repair_service_id"], name: "index_repair_prices_on_repair_service_id"
  end

  create_table "repair_services", id: :serial, force: :cascade do |t|
    t.integer "repair_group_id"
    t.string "name", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "client_info"
    t.boolean "is_positive_price", default: false
    t.boolean "difficult", default: false
    t.boolean "is_body_repair", default: false
    t.index ["repair_group_id"], name: "index_repair_services_on_repair_group_id"
  end

  create_table "repair_tasks", id: :serial, force: :cascade do |t|
    t.integer "repair_service_id"
    t.integer "device_task_id"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "store_id"
    t.integer "repairer_id"
    t.index ["device_task_id"], name: "index_repair_tasks_on_device_task_id"
    t.index ["repair_service_id"], name: "index_repair_tasks_on_repair_service_id"
    t.index ["repairer_id"], name: "index_repair_tasks_on_repairer_id"
    t.index ["store_id"], name: "index_repair_tasks_on_store_id"
  end

  create_table "report_cards", force: :cascade do |t|
    t.string "content"
    t.integer "position"
    t.bigint "report_column_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "annotation", default: ""
    t.index ["report_column_id"], name: "index_report_cards_on_report_column_id"
  end

  create_table "report_columns", force: :cascade do |t|
    t.string "name"
    t.bigint "reports_board_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["reports_board_id"], name: "index_report_columns_on_reports_board_id"
  end

  create_table "reports_boards", force: :cascade do |t|
    t.string "name"
    t.string "description"
    t.jsonb "cards"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "revaluation_acts", id: :serial, force: :cascade do |t|
    t.integer "price_type_id"
    t.datetime "date"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["price_type_id"], name: "index_revaluation_acts_on_price_type_id"
    t.index ["status"], name: "index_revaluation_acts_on_status"
  end

  create_table "revaluations", id: :serial, force: :cascade do |t|
    t.integer "revaluation_act_id"
    t.integer "product_id"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_revaluations_on_product_id"
    t.index ["revaluation_act_id"], name: "index_revaluations_on_revaluation_act_id"
  end

  create_table "reviews", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "service_job_id"
    t.integer "client_id"
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

  create_table "salaries", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "issued_at"
    t.boolean "is_prepayment"
    t.index ["is_prepayment"], name: "index_salaries_on_is_prepayment"
    t.index ["user_id"], name: "index_salaries_on_user_id"
  end

  create_table "sale_items", id: :serial, force: :cascade do |t|
    t.integer "sale_id"
    t.integer "item_id"
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

  create_table "sales", id: :serial, force: :cascade do |t|
    t.integer "store_id"
    t.integer "user_id"
    t.integer "client_id"
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

  create_table "schedule_days", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "day"
    t.string "hours", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["day"], name: "index_schedule_days_on_day"
    t.index ["user_id"], name: "index_schedule_days_on_user_id"
  end

  create_table "service_feedbacks", id: :serial, force: :cascade do |t|
    t.integer "service_job_id", null: false
    t.datetime "scheduled_on"
    t.integer "postpone_count", default: 0, null: false
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "log"
    t.index ["service_job_id"], name: "index_service_feedbacks_on_service_job_id"
  end

  create_table "service_free_jobs", id: :serial, force: :cascade do |t|
    t.integer "performer_id", null: false
    t.integer "client_id", null: false
    t.integer "task_id", null: false
    t.text "comment"
    t.datetime "performed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "receiver_id"
    t.integer "department_id", null: false
    t.index ["client_id"], name: "index_service_free_jobs_on_client_id"
    t.index ["department_id"], name: "index_service_free_jobs_on_department_id"
    t.index ["performer_id"], name: "index_service_free_jobs_on_performer_id"
    t.index ["receiver_id"], name: "index_service_free_jobs_on_receiver_id"
    t.index ["task_id"], name: "index_service_free_jobs_on_task_id"
  end

  create_table "service_free_tasks", id: :serial, force: :cascade do |t|
    t.string "name", null: false
    t.string "icon"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code"
  end

  create_table "service_job_sortings", force: :cascade do |t|
    t.string "title"
    t.string "direction"
    t.string "column"
    t.integer "user_id"
  end

  create_table "service_job_subscriptions", id: false, force: :cascade do |t|
    t.integer "service_job_id", null: false
    t.integer "subscriber_id", null: false
    t.index ["service_job_id", "subscriber_id"], name: "index_service_job_subscriptions", unique: true
    t.index ["service_job_id"], name: "index_service_job_subscriptions_on_service_job_id"
    t.index ["subscriber_id"], name: "index_service_job_subscriptions_on_subscriber_id"
  end

  create_table "service_job_templates", id: :serial, force: :cascade do |t|
    t.string "field_name"
    t.string "content", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["field_name"], name: "index_service_job_templates_on_field_name"
  end

  create_table "service_job_viewings", id: :serial, force: :cascade do |t|
    t.integer "service_job_id", null: false
    t.integer "user_id", null: false
    t.datetime "time", null: false
    t.string "ip", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_job_id"], name: "index_service_job_viewings_on_service_job_id"
    t.index ["time"], name: "index_service_job_viewings_on_time"
    t.index ["user_id"], name: "index_service_job_viewings_on_user_id"
  end

  create_table "service_jobs", id: :serial, force: :cascade do |t|
    t.integer "device_type_id"
    t.string "ticket_number", limit: 255
    t.integer "client_id"
    t.text "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "done_at"
    t.string "serial_number", limit: 255
    t.integer "location_id"
    t.integer "user_id"
    t.string "security_code", limit: 255
    t.string "status", limit: 255
    t.string "imei", limit: 255
    t.boolean "replaced", default: false
    t.boolean "notify_client", default: false
    t.boolean "client_notified"
    t.datetime "return_at"
    t.string "app_store_pass", limit: 255
    t.text "tech_notice"
    t.string "contact_phone", limit: 255
    t.integer "item_id"
    t.integer "sale_id"
    t.integer "case_color_id"
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
    t.integer "initial_department_id"
    t.string "trademark"
    t.string "completeness"
    t.string "device_group"
    t.datetime "completion_act_printed_at"
    t.bigint "photo_container_id"
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
    t.index ["photo_container_id"], name: "index_service_jobs_on_photo_container_id"
    t.index ["return_at"], name: "index_service_jobs_on_return_at"
    t.index ["sale_id"], name: "index_service_jobs_on_sale_id"
    t.index ["status"], name: "index_service_jobs_on_status"
    t.index ["ticket_number"], name: "index_service_jobs_on_ticket_number"
    t.index ["user_id"], name: "index_service_jobs_on_user_id"
  end

  create_table "service_repair_returns", id: :serial, force: :cascade do |t|
    t.integer "service_job_id", null: false
    t.integer "performer_id", null: false
    t.datetime "performed_at", null: false
    t.index ["performer_id"], name: "index_service_repair_returns_on_performer_id"
    t.index ["service_job_id"], name: "index_service_repair_returns_on_service_job_id"
  end

  create_table "service_sms_notifications", id: :serial, force: :cascade do |t|
    t.integer "sender_id", null: false
    t.datetime "sent_at", null: false
    t.text "message", null: false
    t.string "phone_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sender_id"], name: "index_service_sms_notifications_on_sender_id"
  end

  create_table "settings", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "presentation", limit: 255
    t.text "value"
    t.string "value_type", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.index ["department_id"], name: "index_settings_on_department_id"
    t.index ["name"], name: "index_settings_on_name"
  end

  create_table "spare_part_defects", id: :serial, force: :cascade do |t|
    t.integer "item_id"
    t.integer "contractor_id"
    t.integer "qty", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "repair_part_id"
    t.boolean "is_warranty", default: false, null: false
    t.index ["contractor_id"], name: "index_spare_part_defects_on_contractor_id"
    t.index ["item_id"], name: "index_spare_part_defects_on_item_id"
    t.index ["repair_part_id"], name: "index_spare_part_defects_on_repair_part_id"
  end

  create_table "spare_parts", id: :serial, force: :cascade do |t|
    t.integer "repair_service_id"
    t.integer "product_id"
    t.integer "quantity"
    t.integer "warranty_term"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_spare_parts_on_product_id"
    t.index ["repair_service_id"], name: "index_spare_parts_on_repair_service_id"
  end

  create_table "stolen_phones", id: :serial, force: :cascade do |t|
    t.string "imei", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "serial_number", limit: 255
    t.integer "client_id"
    t.text "client_comment"
    t.integer "item_id"
    t.index ["client_id"], name: "index_stolen_phones_on_client_id"
    t.index ["imei"], name: "index_stolen_phones_on_imei"
    t.index ["item_id"], name: "index_stolen_phones_on_item_id"
    t.index ["serial_number"], name: "index_stolen_phones_on_serial_number"
  end

  create_table "store_items", id: :serial, force: :cascade do |t|
    t.integer "item_id"
    t.integer "store_id"
    t.integer "quantity", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_store_items_on_item_id"
    t.index ["store_id"], name: "index_store_items_on_store_id"
  end

  create_table "store_products", id: :serial, force: :cascade do |t|
    t.integer "store_id"
    t.integer "product_id"
    t.integer "warning_quantity"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "store_id"], name: "index_store_products_on_product_id_and_store_id"
    t.index ["product_id"], name: "index_store_products_on_product_id"
    t.index ["store_id"], name: "index_store_products_on_store_id"
  end

  create_table "stores", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "code", limit: 255
    t.string "kind", limit: 255
    t.integer "department_id"
    t.boolean "hidden"
    t.index ["code"], name: "index_stores_on_code"
    t.index ["department_id"], name: "index_stores_on_department_id"
  end

  create_table "substitute_phones", id: :serial, force: :cascade do |t|
    t.integer "item_id"
    t.text "condition", null: false
    t.integer "service_job_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.boolean "archived"
    t.index ["department_id"], name: "index_substitute_phones_on_department_id"
    t.index ["item_id"], name: "index_substitute_phones_on_item_id"
    t.index ["service_job_id"], name: "index_substitute_phones_on_service_job_id", unique: true
  end

  create_table "supplies", id: :serial, force: :cascade do |t|
    t.integer "supply_report_id"
    t.integer "supply_category_id"
    t.string "name", limit: 255
    t.integer "quantity"
    t.decimal "cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["supply_category_id"], name: "index_supplies_on_supply_category_id"
    t.index ["supply_report_id"], name: "index_supplies_on_supply_report_id"
  end

  create_table "supply_categories", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.string "ancestry", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestry"], name: "index_supply_categories_on_ancestry"
  end

  create_table "supply_reports", id: :serial, force: :cascade do |t|
    t.date "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.index ["department_id"], name: "index_supply_reports_on_department_id"
  end

  create_table "supply_requests", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.string "status", limit: 255
    t.string "object", limit: 255
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "department_id"
    t.index ["department_id"], name: "index_supply_requests_on_department_id"
    t.index ["status"], name: "index_supply_requests_on_status"
    t.index ["user_id"], name: "index_supply_requests_on_user_id"
  end

  create_table "task_templates", id: :serial, force: :cascade do |t|
    t.text "content", null: false
    t.string "icon"
    t.string "ancestry"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestry"], name: "index_task_templates_on_ancestry"
  end

  create_table "tasks", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.integer "duration"
    t.decimal "cost"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "priority", default: 0
    t.string "role", limit: 255
    t.integer "product_id"
    t.boolean "hidden", default: false
    t.string "code"
    t.string "location_code"
    t.string "color", default: ""
    t.integer "position", null: false
    t.index ["name"], name: "index_tasks_on_name"
    t.index ["product_id"], name: "index_tasks_on_product_id"
    t.index ["role"], name: "index_tasks_on_role"
  end

  create_table "timesheet_days", id: :serial, force: :cascade do |t|
    t.date "date"
    t.integer "user_id"
    t.string "status", limit: 255
    t.integer "work_mins"
    t.time "time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["date"], name: "index_timesheet_days_on_date"
    t.index ["status"], name: "index_timesheet_days_on_status"
    t.index ["user_id"], name: "index_timesheet_days_on_user_id"
  end

  create_table "top_salables", id: :serial, force: :cascade do |t|
    t.integer "product_id"
    t.string "name", limit: 255
    t.string "ancestry", limit: 255
    t.integer "position"
    t.string "color", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ancestry"], name: "index_top_salables_on_ancestry"
    t.index ["product_id"], name: "index_top_salables_on_product_id"
  end

  create_table "trade_in_device_evaluations", force: :cascade do |t|
    t.string "name"
    t.bigint "product_group_id"
    t.decimal "min_value"
    t.decimal "max_value"
    t.decimal "lack_of_kit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "option_values", default: [], array: true
    t.index ["product_group_id"], name: "index_trade_in_device_evaluations_on_product_group_id"
  end

  create_table "trade_in_devices", id: :serial, force: :cascade do |t|
    t.integer "number"
    t.datetime "received_at", null: false
    t.integer "item_id", null: false
    t.integer "receiver_id"
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
    t.integer "department_id", null: false
    t.boolean "confirmed", default: false, null: false
    t.boolean "extended_guarantee"
    t.integer "sale_amount"
    t.integer "client_id"
    t.index ["client_id"], name: "index_trade_in_devices_on_client_id"
    t.index ["department_id"], name: "index_trade_in_devices_on_department_id"
    t.index ["item_id"], name: "index_trade_in_devices_on_item_id"
    t.index ["receiver_id"], name: "index_trade_in_devices_on_receiver_id"
  end

  create_table "user_abilities", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "ability_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ability_id"], name: "index_user_abilities_on_ability_id"
    t.index ["user_id", "ability_id"], name: "index_user_abilities_on_user_id_and_ability_id", unique: true
    t.index ["user_id"], name: "index_user_abilities_on_user_id"
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "username", limit: 255
    t.string "role", limit: 255
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", limit: 255, default: "", null: false
    t.string "reset_password_token", limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip", limit: 255
    t.string "last_sign_in_ip", limit: 255
    t.string "authentication_token", limit: 255
    t.string "email", limit: 255, default: ""
    t.integer "location_id"
    t.string "photo", limit: 255
    t.string "surname", limit: 255
    t.string "name", limit: 255
    t.string "patronymic", limit: 255
    t.date "birthday"
    t.date "hiring_date"
    t.date "salary_date"
    t.string "prepayment", limit: 255
    t.text "wish"
    t.string "card_number", limit: 255
    t.string "color", limit: 255
    t.bigint "abilities_mask"
    t.boolean "schedule"
    t.integer "position"
    t.boolean "is_fired"
    t.string "job_title", limit: 255
    t.integer "store_id"
    t.integer "department_id"
    t.integer "session_duration"
    t.string "phone_number", limit: 255
    t.boolean "department_autochangeable", default: true, null: false
    t.boolean "can_help_in_repair", default: false
    t.string "uniform_sex"
    t.string "uniform_size"
    t.integer "activities_mask"
    t.string "wishlist", default: [], array: true
    t.text "hobby"
    t.boolean "can_help_in_mac_service", default: false
    t.string "work_phone"
    t.integer "service_job_sorting_id"
    t.boolean "is_senior", default: false
    t.datetime "dismissed_date"
    t.bigint "dismissal_reason_id"
    t.text "dismissal_comment"
    t.boolean "fixed_main_menu", default: false
    t.boolean "need_to_select_window", default: false
    t.bigint "elqueue_window_id"
    t.boolean "remember_pause", default: false, null: false
    t.index ["authentication_token"], name: "index_users_on_authentication_token", unique: true
    t.index ["card_number"], name: "index_users_on_card_number"
    t.index ["department_id"], name: "index_users_on_department_id"
    t.index ["dismissal_reason_id"], name: "index_users_on_dismissal_reason_id"
    t.index ["elqueue_window_id"], name: "index_users_on_elqueue_window_id"
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
    t.index ["username"], name: "index_users_on_username"
  end

  create_table "waiting_clients", force: :cascade do |t|
    t.bigint "queue_item_id", null: false
    t.integer "position", default: 0
    t.string "phone_number"
    t.bigint "client_id"
    t.datetime "ticket_issued_at"
    t.datetime "ticket_called_at"
    t.datetime "ticket_served_at"
    t.string "status", default: "waiting", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "elqueue_window_id"
    t.string "ticket_number", null: false
    t.integer "priority", default: 0, null: false
    t.integer "attached_window"
    t.boolean "completed_automatically", default: false, null: false
    t.index ["client_id"], name: "index_waiting_clients_on_client_id"
    t.index ["elqueue_window_id"], name: "index_waiting_clients_on_elqueue_window_id"
    t.index ["queue_item_id"], name: "index_waiting_clients_on_queue_item_id"
  end

  create_table "wiki_documents", force: :cascade do |t|
    t.bigint "wiki_page_id"
    t.string "file"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["wiki_page_id"], name: "index_wiki_documents_on_wiki_page_id"
  end

  create_table "wiki_page_attachments", id: :serial, force: :cascade do |t|
    t.integer "page_id", null: false
    t.string "wiki_page_attachment_file_name", limit: 255
    t.string "wiki_page_attachment_content_type", limit: 255
    t.integer "wiki_page_attachment_file_size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "wiki_page_categories", force: :cascade do |t|
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "color_tag", default: "ffffff"
    t.index ["title"], name: "index_wiki_page_categories_on_title", unique: true
  end

  create_table "wiki_page_versions", id: :serial, force: :cascade do |t|
    t.integer "page_id", null: false
    t.integer "updator_id"
    t.integer "number"
    t.string "comment", limit: 255
    t.string "path", limit: 255
    t.string "title", limit: 255
    t.text "content"
    t.datetime "updated_at"
    t.index ["page_id"], name: "index_wiki_page_versions_on_page_id"
    t.index ["updator_id"], name: "index_wiki_page_versions_on_updator_id"
  end

  create_table "wiki_pages", id: :serial, force: :cascade do |t|
    t.integer "creator_id"
    t.integer "updator_id"
    t.string "path", limit: 255
    t.string "title", limit: 255
    t.text "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "private"
    t.integer "wiki_page_category_id"
    t.boolean "senior", default: false
    t.string "images", default: [], array: true
    t.boolean "superadmin", default: false
    t.index ["creator_id"], name: "index_wiki_pages_on_creator_id"
    t.index ["path"], name: "index_wiki_pages_on_path", unique: true
  end

  add_foreign_key "departments", "brands"
  add_foreign_key "departments", "cities"
  add_foreign_key "electronic_queues", "departments"
  add_foreign_key "elqueue_ticket_movements", "waiting_clients"
  add_foreign_key "elqueue_windows", "electronic_queues"
  add_foreign_key "faults", "fault_kinds", column: "kind_id"
  add_foreign_key "faults", "users", column: "causer_id"
  add_foreign_key "faults", "users", column: "issued_by_id"
  add_foreign_key "kanban_boards_users", "kanban_boards"
  add_foreign_key "kanban_boards_users", "users"
  add_foreign_key "kanban_cards", "kanban_columns", column: "column_id"
  add_foreign_key "kanban_cards", "users", column: "author_id"
  add_foreign_key "kanban_cards_users", "kanban_cards"
  add_foreign_key "kanban_cards_users", "users"
  add_foreign_key "kanban_columns", "kanban_boards", column: "board_id"
  add_foreign_key "lost_devices", "service_jobs"
  add_foreign_key "messages", "departments"
  add_foreign_key "notifications", "users"
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
  add_foreign_key "queue_items", "electronic_queues"
  add_foreign_key "quick_orders", "clients"
  add_foreign_key "repair_prices", "departments"
  add_foreign_key "repair_prices", "repair_services"
  add_foreign_key "repair_tasks", "users", column: "repairer_id"
  add_foreign_key "report_cards", "report_columns"
  add_foreign_key "report_columns", "reports_boards"
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
  add_foreign_key "service_jobs", "photo_containers"
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
  add_foreign_key "trade_in_device_evaluations", "product_groups"
  add_foreign_key "trade_in_devices", "clients"
  add_foreign_key "trade_in_devices", "departments"
  add_foreign_key "trade_in_devices", "items"
  add_foreign_key "trade_in_devices", "users", column: "receiver_id"
  add_foreign_key "user_abilities", "abilities"
  add_foreign_key "user_abilities", "users"
  add_foreign_key "users", "dismissal_reasons"
  add_foreign_key "users", "elqueue_windows"
  add_foreign_key "waiting_clients", "clients"
  add_foreign_key "waiting_clients", "elqueue_windows"
  add_foreign_key "waiting_clients", "queue_items"
  add_foreign_key "wiki_documents", "wiki_pages"
end
