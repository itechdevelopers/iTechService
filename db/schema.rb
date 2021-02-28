# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20210223090846) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "citext"
  enable_extension "hstore"

  create_table "announcements", force: :cascade do |t|
    t.string   "content",       limit: 255
    t.string   "kind",          limit: 255, null: false
    t.integer  "user_id"
    t.boolean  "active"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.integer  "department_id"
  end

  add_index "announcements", ["department_id"], name: "index_announcements_on_department_id", using: :btree
  add_index "announcements", ["kind"], name: "index_announcements_on_kind", using: :btree
  add_index "announcements", ["user_id"], name: "index_announcements_on_user_id", using: :btree

  create_table "announcements_users", force: :cascade do |t|
    t.integer "announcement_id"
    t.integer "user_id"
  end

  create_table "banks", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "batches", force: :cascade do |t|
    t.integer  "purchase_id"
    t.integer  "item_id"
    t.decimal  "price",       precision: 8, scale: 2
    t.integer  "quantity"
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  add_index "batches", ["item_id"], name: "index_batches_on_item_id", using: :btree
  add_index "batches", ["purchase_id"], name: "index_batches_on_purchase_id", using: :btree

  create_table "bonus_types", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "bonuses", force: :cascade do |t|
    t.integer  "bonus_type_id"
    t.text     "comment"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "bonuses", ["bonus_type_id"], name: "index_bonuses_on_bonus_type_id", using: :btree

  create_table "brands", force: :cascade do |t|
    t.string   "name",       null: false
    t.string   "logo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "carriers", force: :cascade do |t|
    t.string   "name",       limit: 255, null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "case_colors", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.string   "color",      limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "cash_drawers", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.integer  "department_id"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "cash_drawers", ["department_id"], name: "index_cash_drawers_on_department_id", using: :btree

  create_table "cash_operations", force: :cascade do |t|
    t.integer  "cash_shift_id"
    t.integer  "user_id"
    t.boolean  "is_out",        default: false
    t.decimal  "value"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.text     "comment"
  end

  add_index "cash_operations", ["cash_shift_id"], name: "index_cash_operations_on_cash_shift_id", using: :btree
  add_index "cash_operations", ["user_id"], name: "index_cash_operations_on_user_id", using: :btree

  create_table "cash_shifts", force: :cascade do |t|
    t.boolean  "is_closed",      default: false
    t.integer  "user_id"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.datetime "closed_at"
    t.integer  "cash_drawer_id"
  end

  add_index "cash_shifts", ["cash_drawer_id"], name: "index_cash_shifts_on_cash_drawer_id", using: :btree
  add_index "cash_shifts", ["user_id"], name: "index_cash_shifts_on_user_id", using: :btree

  create_table "cities", force: :cascade do |t|
    t.string   "name",       null: false
    t.string   "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string   "time_zone"
  end

  create_table "ckeditor_assets", force: :cascade do |t|
    t.string   "data_file_name",    limit: 255, null: false
    t.string   "data_content_type", limit: 255
    t.integer  "data_file_size"
    t.integer  "assetable_id"
    t.string   "assetable_type",    limit: 30
    t.string   "type",              limit: 30
    t.integer  "width"
    t.integer  "height"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
  end

  add_index "ckeditor_assets", ["assetable_type", "assetable_id"], name: "idx_ckeditor_assetable", using: :btree
  add_index "ckeditor_assets", ["assetable_type", "type", "assetable_id"], name: "idx_ckeditor_assetable_type", using: :btree

  create_table "client_categories", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.string   "color",      limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "client_characteristics", force: :cascade do |t|
    t.integer  "client_category_id"
    t.text     "comment"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

  add_index "client_characteristics", ["client_category_id"], name: "index_client_characteristics_on_client_category_id", using: :btree

  create_table "clients", force: :cascade do |t|
    t.string   "name",                     limit: 255
    t.string   "phone_number",             limit: 255
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
    t.string   "card_number",              limit: 255
    t.string   "full_phone_number",        limit: 255
    t.string   "surname",                  limit: 255
    t.string   "patronymic",               limit: 255
    t.date     "birthday"
    t.string   "email",                    limit: 255
    t.text     "admin_info"
    t.string   "contact_phone",            limit: 255
    t.integer  "client_characteristic_id"
    t.integer  "category"
    t.integer  "department_id"
  end

  add_index "clients", ["card_number"], name: "index_clients_on_card_number", using: :btree
  add_index "clients", ["category"], name: "index_clients_on_category", using: :btree
  add_index "clients", ["department_id"], name: "index_clients_on_department_id", using: :btree
  add_index "clients", ["email"], name: "index_clients_on_email", using: :btree
  add_index "clients", ["full_phone_number"], name: "index_clients_on_full_phone_number", using: :btree
  add_index "clients", ["name"], name: "index_clients_on_name", using: :btree
  add_index "clients", ["patronymic"], name: "index_clients_on_patronymic", using: :btree
  add_index "clients", ["phone_number"], name: "index_clients_on_phone_number", using: :btree
  add_index "clients", ["surname"], name: "index_clients_on_surname", using: :btree

  create_table "comments", force: :cascade do |t|
    t.integer  "user_id",                      null: false
    t.integer  "commentable_id",               null: false
    t.string   "commentable_type", limit: 255, null: false
    t.text     "content",                      null: false
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  add_index "comments", ["commentable_id", "commentable_type"], name: "index_comments_on_commentable_id_and_commentable_type", using: :btree
  add_index "comments", ["commentable_id"], name: "index_comments_on_commentable_id", using: :btree
  add_index "comments", ["user_id"], name: "index_comments_on_user_id", using: :btree

  create_table "contractors", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "deduction_acts", force: :cascade do |t|
    t.integer  "status",     default: 0, null: false
    t.datetime "date"
    t.integer  "store_id"
    t.integer  "user_id"
    t.text     "comment"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "deduction_acts", ["store_id"], name: "index_deduction_acts_on_store_id", using: :btree
  add_index "deduction_acts", ["user_id"], name: "index_deduction_acts_on_user_id", using: :btree

  create_table "deduction_items", force: :cascade do |t|
    t.integer  "item_id",                      null: false
    t.integer  "deduction_act_id"
    t.integer  "quantity",         default: 1, null: false
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  add_index "deduction_items", ["deduction_act_id"], name: "index_deduction_items_on_deduction_act_id", using: :btree
  add_index "deduction_items", ["item_id"], name: "index_deduction_items_on_item_id", using: :btree

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",               default: 0
    t.integer  "attempts",               default: 0
    t.text     "handler"
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by",  limit: 255
    t.string   "queue",      limit: 255
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
  end

  add_index "delayed_jobs", ["priority", "run_at"], name: "delayed_jobs_priority", using: :btree

  create_table "departments", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.string   "code",          limit: 255
    t.integer  "role"
    t.string   "url",           limit: 255
    t.string   "address",       limit: 255
    t.string   "contact_phone", limit: 255
    t.text     "schedule"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "printer"
    t.string   "ip_network"
    t.integer  "city_id",                   null: false
    t.integer  "brand_id"
    t.string   "short_name"
  end

  add_index "departments", ["brand_id"], name: "index_departments_on_brand_id", using: :btree
  add_index "departments", ["city_id"], name: "index_departments_on_city_id", using: :btree
  add_index "departments", ["code"], name: "index_departments_on_code", using: :btree
  add_index "departments", ["role"], name: "index_departments_on_role", using: :btree

  create_table "device_notes", force: :cascade do |t|
    t.integer  "service_job_id", null: false
    t.integer  "user_id",        null: false
    t.text     "content",        null: false
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_index "device_notes", ["service_job_id"], name: "index_device_notes_on_service_job_id", using: :btree
  add_index "device_notes", ["user_id"], name: "index_device_notes_on_user_id", using: :btree

  create_table "device_tasks", force: :cascade do |t|
    t.integer  "service_job_id"
    t.integer  "task_id"
    t.integer  "done",           default: 0
    t.text     "comment"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.decimal  "cost"
    t.datetime "done_at"
    t.text     "user_comment"
    t.integer  "performer_id"
  end

  add_index "device_tasks", ["done"], name: "index_device_tasks_on_done", using: :btree
  add_index "device_tasks", ["done_at"], name: "index_device_tasks_on_done_at", using: :btree
  add_index "device_tasks", ["performer_id"], name: "index_device_tasks_on_performer_id", using: :btree
  add_index "device_tasks", ["service_job_id"], name: "index_device_tasks_on_service_job_id", using: :btree
  add_index "device_tasks", ["task_id"], name: "index_device_tasks_on_task_id", using: :btree

  create_table "device_types", force: :cascade do |t|
    t.string   "name",                limit: 255
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.string   "ancestry",            limit: 255
    t.integer  "qty_for_replacement",             default: 0
    t.integer  "qty_replaced",                    default: 0
    t.integer  "qty_shop"
    t.integer  "qty_store"
    t.integer  "qty_reserve"
    t.integer  "expected_during"
    t.integer  "code_1c"
  end

  add_index "device_types", ["ancestry"], name: "index_device_types_on_ancestry", using: :btree
  add_index "device_types", ["code_1c"], name: "index_device_types_on_code_1c", using: :btree
  add_index "device_types", ["name"], name: "index_device_types_on_name", using: :btree

  create_table "discounts", force: :cascade do |t|
    t.integer  "value"
    t.integer  "limit"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "discounts", ["limit"], name: "index_discounts_on_limit", using: :btree

  create_table "duty_days", force: :cascade do |t|
    t.integer  "user_id"
    t.date     "day"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.string   "kind",       limit: 255
  end

  add_index "duty_days", ["day"], name: "index_duty_days_on_day", using: :btree
  add_index "duty_days", ["kind"], name: "index_duty_days_on_kind", using: :btree
  add_index "duty_days", ["user_id"], name: "index_duty_days_on_user_id", using: :btree

  create_table "fault_kinds", force: :cascade do |t|
    t.string   "name"
    t.string   "icon"
    t.boolean  "is_permanent", default: false, null: false
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
    t.text     "description"
    t.boolean  "financial",    default: false, null: false
    t.string   "penalties"
  end

  create_table "faults", force: :cascade do |t|
    t.integer  "causer_id",  null: false
    t.integer  "kind_id",    null: false
    t.date     "date"
    t.text     "comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer  "penalty"
  end

  add_index "faults", ["causer_id"], name: "index_faults_on_causer_id", using: :btree
  add_index "faults", ["kind_id"], name: "index_faults_on_kind_id", using: :btree

  create_table "favorite_links", force: :cascade do |t|
    t.integer  "owner_id",   null: false
    t.string   "name"
    t.string   "url",        null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "favorite_links", ["owner_id"], name: "index_favorite_links_on_owner_id", using: :btree

  create_table "feature_types", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.string   "kind",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "feature_types", ["kind"], name: "index_feature_types_on_code", using: :btree

  create_table "feature_types_product_categories", force: :cascade do |t|
    t.integer "product_category_id"
    t.integer "feature_type_id"
  end

  create_table "features", force: :cascade do |t|
    t.integer  "feature_type_id"
    t.integer  "item_id"
    t.string   "value",           limit: 255
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "features", ["feature_type_id"], name: "index_features_on_feature_type_id", using: :btree
  add_index "features", ["item_id"], name: "index_features_on_item_id", using: :btree
  add_index "features", ["value"], name: "index_features_on_value", using: :btree

  create_table "features_items", force: :cascade do |t|
    t.integer "feature_id"
    t.integer "item_id"
  end

  create_table "gift_certificates", force: :cascade do |t|
    t.string   "number",        limit: 255
    t.integer  "nominal"
    t.integer  "status"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.integer  "consumed"
    t.integer  "department_id"
  end

  add_index "gift_certificates", ["department_id"], name: "index_gift_certificates_on_department_id", using: :btree
  add_index "gift_certificates", ["number"], name: "index_gift_certificates_on_number", using: :btree

  create_table "history_records", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "object_id"
    t.string   "object_type", limit: 255
    t.string   "column_name", limit: 255
    t.string   "column_type", limit: 255
    t.datetime "deleted_at"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.text     "old_value"
    t.text     "new_value"
  end

  add_index "history_records", ["column_name"], name: "index_history_records_on_column_name", using: :btree
  add_index "history_records", ["object_id", "object_type"], name: "index_history_records_on_object_id_and_object_type", using: :btree
  add_index "history_records", ["user_id"], name: "index_history_records_on_user_id", using: :btree

  create_table "imported_sales", force: :cascade do |t|
    t.integer  "device_type_id"
    t.string   "imei",           limit: 255
    t.string   "serial_number",  limit: 255
    t.datetime "sold_at"
    t.string   "quantity",       limit: 255
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  add_index "imported_sales", ["device_type_id"], name: "index_imported_sales_on_device_type_id", using: :btree

  create_table "infos", force: :cascade do |t|
    t.string   "title",         limit: 255,                 null: false
    t.text     "content",                                   null: false
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.boolean  "important",                 default: false
    t.integer  "recipient_id"
    t.boolean  "is_archived",               default: false
    t.integer  "department_id"
  end

  add_index "infos", ["department_id"], name: "index_infos_on_department_id", using: :btree
  add_index "infos", ["recipient_id"], name: "index_infos_on_recipient_id", using: :btree
  add_index "infos", ["title"], name: "index_infos_on_title", using: :btree

  create_table "installment_plans", force: :cascade do |t|
    t.integer  "user_id",                                null: false
    t.string   "object",     limit: 255
    t.integer  "cost"
    t.date     "issued_at"
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
    t.boolean  "is_closed",              default: false
  end

  add_index "installment_plans", ["is_closed"], name: "index_installment_plans_on_is_closed", using: :btree
  add_index "installment_plans", ["user_id"], name: "index_installment_plans_on_user_id", using: :btree

  create_table "installments", force: :cascade do |t|
    t.integer  "installment_plan_id"
    t.integer  "value"
    t.date     "paid_at"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
  end

  add_index "installments", ["installment_plan_id"], name: "index_installments_on_installment_plan_id", using: :btree

  create_table "items", force: :cascade do |t|
    t.integer  "product_id"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.string   "barcode_num", limit: 255
  end

  add_index "items", ["barcode_num"], name: "index_items_on_barcode_num", using: :btree
  add_index "items", ["product_id"], name: "index_items_on_product_id", using: :btree

  create_table "karma_groups", force: :cascade do |t|
    t.integer  "bonus_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "karma_groups", ["bonus_id"], name: "index_karma_groups_on_bonus_id", using: :btree

  create_table "karmas", force: :cascade do |t|
    t.boolean  "good"
    t.text     "comment"
    t.integer  "user_id"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.integer  "karma_group_id"
  end

  add_index "karmas", ["karma_group_id"], name: "index_karmas_on_karma_group_id", using: :btree
  add_index "karmas", ["user_id"], name: "index_karmas_on_user_id", using: :btree

  create_table "locations", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.string   "ancestry",      limit: 255
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.boolean  "schedule"
    t.integer  "position",                  default: 0
    t.string   "code",          limit: 255
    t.integer  "department_id"
    t.boolean  "hidden",                    default: false
    t.integer  "storage_term"
  end

  add_index "locations", ["ancestry"], name: "index_locations_on_ancestry", using: :btree
  add_index "locations", ["code"], name: "index_locations_on_code", using: :btree
  add_index "locations", ["department_id"], name: "index_locations_on_department_id", using: :btree
  add_index "locations", ["name"], name: "index_locations_on_name", using: :btree
  add_index "locations", ["schedule"], name: "index_locations_on_schedule", using: :btree

  create_table "lost_devices", force: :cascade do |t|
    t.integer  "service_job_id", null: false
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_index "lost_devices", ["service_job_id"], name: "index_lost_devices_on_service_job_id", unique: true, using: :btree

  create_table "media_orders", force: :cascade do |t|
    t.datetime "time"
    t.string   "name",       limit: 255
    t.string   "phone",      limit: 255
    t.text     "content"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "messages", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "content",        limit: 255
    t.integer  "recipient_id"
    t.string   "recipient_type", limit: 255
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.integer  "department_id",              null: false
  end

  add_index "messages", ["department_id"], name: "index_messages_on_department_id", using: :btree
  add_index "messages", ["recipient_id"], name: "index_messages_on_recipient_id", using: :btree
  add_index "messages", ["user_id"], name: "index_messages_on_user_id", using: :btree

  create_table "movement_acts", force: :cascade do |t|
    t.datetime "date"
    t.integer  "store_id"
    t.integer  "dst_store_id"
    t.integer  "user_id"
    t.integer  "status"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.text     "comment"
  end

  add_index "movement_acts", ["dst_store_id"], name: "index_movement_acts_on_dst_store_id", using: :btree
  add_index "movement_acts", ["store_id"], name: "index_movement_acts_on_store_id", using: :btree
  add_index "movement_acts", ["user_id"], name: "index_movement_acts_on_user_id", using: :btree

  create_table "movement_items", force: :cascade do |t|
    t.integer  "movement_act_id"
    t.integer  "item_id"
    t.integer  "quantity"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "movement_items", ["item_id"], name: "index_movement_items_on_item_id", using: :btree
  add_index "movement_items", ["movement_act_id"], name: "index_movement_items_on_movement_act_id", using: :btree

  create_table "option_types", force: :cascade do |t|
    t.string   "name",                   null: false
    t.string   "code"
    t.integer  "position",   default: 0, null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "option_types", ["code"], name: "index_option_types_on_code", using: :btree
  add_index "option_types", ["name"], name: "index_option_types_on_name", using: :btree

  create_table "option_values", force: :cascade do |t|
    t.integer  "option_type_id",             null: false
    t.string   "name",                       null: false
    t.string   "code"
    t.integer  "position",       default: 0, null: false
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  add_index "option_values", ["code"], name: "index_option_values_on_code", using: :btree
  add_index "option_values", ["name"], name: "index_option_values_on_name", using: :btree
  add_index "option_values", ["option_type_id"], name: "index_option_values_on_option_type_id", using: :btree

  create_table "order_notes", force: :cascade do |t|
    t.integer  "order_id",   null: false
    t.integer  "author_id",  null: false
    t.text     "content",    null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "order_notes", ["author_id"], name: "index_order_notes_on_author_id", using: :btree
  add_index "order_notes", ["order_id"], name: "index_order_notes_on_order_id", using: :btree

  create_table "orders", force: :cascade do |t|
    t.string   "number",            limit: 255
    t.integer  "customer_id"
    t.string   "customer_type",     limit: 255
    t.string   "object_kind",       limit: 255
    t.string   "object",            limit: 255
    t.date     "desired_date"
    t.string   "status",            limit: 255
    t.text     "comment"
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.integer  "user_id"
    t.text     "user_comment"
    t.integer  "department_id"
    t.integer  "quantity",                      default: 1
    t.integer  "priority",                      default: 1
    t.decimal  "approximate_price"
    t.text     "object_url"
    t.text     "model"
    t.integer  "prepayment"
    t.integer  "payment_method"
    t.string   "picture"
  end

  add_index "orders", ["customer_id", "customer_type"], name: "index_orders_on_customer_id_and_customer_type", using: :btree
  add_index "orders", ["customer_id"], name: "index_orders_on_customer_id", using: :btree
  add_index "orders", ["department_id"], name: "index_orders_on_department_id", using: :btree
  add_index "orders", ["object_kind"], name: "index_orders_on_object_kind", using: :btree
  add_index "orders", ["priority"], name: "index_orders_on_priority", using: :btree
  add_index "orders", ["status"], name: "index_orders_on_status", using: :btree
  add_index "orders", ["user_id"], name: "index_orders_on_user_id", using: :btree

  create_table "payment_types", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.string   "kind",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "payment_types", ["kind"], name: "index_payment_types_on_kind", using: :btree

  create_table "payments", force: :cascade do |t|
    t.string   "kind",                limit: 255
    t.decimal  "value"
    t.integer  "sale_id"
    t.integer  "bank_id"
    t.integer  "gift_certificate_id"
    t.string   "device_name",         limit: 255
    t.string   "device_number",       limit: 255
    t.string   "client_info",         limit: 255
    t.string   "appraiser",           limit: 255
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
  end

  add_index "payments", ["bank_id"], name: "index_payments_on_bank_id", using: :btree
  add_index "payments", ["gift_certificate_id"], name: "index_payments_on_gift_certificate_id", using: :btree
  add_index "payments", ["kind"], name: "index_payments_on_kind", using: :btree
  add_index "payments", ["sale_id"], name: "index_payments_on_sale_id", using: :btree

  create_table "phone_substitutions", force: :cascade do |t|
    t.integer  "substitute_phone_id", null: false
    t.integer  "service_job_id",      null: false
    t.integer  "issuer_id",           null: false
    t.datetime "issued_at",           null: false
    t.integer  "receiver_id"
    t.boolean  "condition_match"
    t.datetime "withdrawn_at"
    t.datetime "created_at",          null: false
    t.datetime "updated_at",          null: false
  end

  add_index "phone_substitutions", ["issuer_id"], name: "index_phone_substitutions_on_issuer_id", using: :btree
  add_index "phone_substitutions", ["receiver_id"], name: "index_phone_substitutions_on_receiver_id", using: :btree
  add_index "phone_substitutions", ["service_job_id"], name: "index_phone_substitutions_on_service_job_id", using: :btree
  add_index "phone_substitutions", ["substitute_phone_id"], name: "index_phone_substitutions_on_substitute_phone_id", using: :btree

  create_table "price_types", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.integer  "kind"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "price_types", ["kind"], name: "index_price_types_on_kind", using: :btree

  create_table "price_types_stores", force: :cascade do |t|
    t.integer "price_type_id"
    t.integer "store_id"
  end

  add_index "price_types_stores", ["price_type_id"], name: "index_price_types_stores_on_price_type_id", using: :btree
  add_index "price_types_stores", ["store_id"], name: "index_price_types_stores_on_store_id", using: :btree

  create_table "prices", force: :cascade do |t|
    t.string   "file",          limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.integer  "department_id"
  end

  add_index "prices", ["department_id"], name: "index_prices_on_department_id", using: :btree

  create_table "product_categories", force: :cascade do |t|
    t.string   "name",               limit: 255
    t.boolean  "feature_accounting",             default: false
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.integer  "warranty_term"
    t.string   "kind",               limit: 255
    t.boolean  "request_price"
  end

  add_index "product_categories", ["kind"], name: "index_product_categories_on_kind", using: :btree

  create_table "product_groups", force: :cascade do |t|
    t.string   "name",                limit: 255
    t.string   "ancestry",            limit: 255
    t.integer  "product_category_id"
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.integer  "ancestry_depth",                  default: 0
    t.string   "code",                limit: 255
    t.integer  "position",                        default: 0, null: false
    t.integer  "warranty_term",                   default: 0, null: false
  end

  add_index "product_groups", ["ancestry"], name: "index_product_groups_on_ancestry", using: :btree
  add_index "product_groups", ["code"], name: "index_product_groups_on_code", using: :btree
  add_index "product_groups", ["product_category_id"], name: "index_product_groups_on_product_category_id", using: :btree

  create_table "product_groups_option_values", id: false, force: :cascade do |t|
    t.integer "product_group_id"
    t.integer "option_value_id"
  end

  add_index "product_groups_option_values", ["option_value_id"], name: "index_product_groups_option_values_on_option_value_id", using: :btree
  add_index "product_groups_option_values", ["product_group_id"], name: "index_product_groups_option_values_on_product_group_id", using: :btree

  create_table "product_options", id: false, force: :cascade do |t|
    t.integer "product_id",      null: false
    t.integer "option_value_id", null: false
  end

  add_index "product_options", ["option_value_id"], name: "index_product_options_on_option_value_id", using: :btree
  add_index "product_options", ["product_id"], name: "index_product_options_on_product_id", using: :btree

  create_table "product_prices", force: :cascade do |t|
    t.integer  "product_id"
    t.integer  "price_type_id"
    t.datetime "date"
    t.decimal  "value"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.integer  "department_id"
  end

  add_index "product_prices", ["department_id"], name: "index_product_prices_on_department_id", using: :btree
  add_index "product_prices", ["price_type_id"], name: "index_product_prices_on_price_type_id", using: :btree
  add_index "product_prices", ["product_id"], name: "index_product_prices_on_product_id", using: :btree

  create_table "product_relations", force: :cascade do |t|
    t.integer  "parent_id"
    t.string   "parent_type",    limit: 255
    t.integer  "relatable_id"
    t.string   "relatable_type", limit: 255
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
  end

  add_index "product_relations", ["parent_type", "parent_id"], name: "index_product_relations_on_parent_type_and_parent_id", using: :btree
  add_index "product_relations", ["relatable_type", "relatable_id"], name: "index_product_relations_on_relatable_type_and_relatable_id", using: :btree

  create_table "products", force: :cascade do |t|
    t.string   "name",                limit: 255
    t.string   "code",                limit: 255
    t.integer  "product_group_id"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.integer  "warranty_term"
    t.integer  "device_type_id"
    t.integer  "quantity_threshold"
    t.text     "comment"
    t.integer  "product_category_id"
  end

  add_index "products", ["code"], name: "index_products_on_code", using: :btree
  add_index "products", ["device_type_id"], name: "index_products_on_device_type_id", using: :btree
  add_index "products", ["name"], name: "index_products_on_name", using: :btree
  add_index "products", ["product_category_id"], name: "index_products_on_product_category_id", using: :btree
  add_index "products", ["product_group_id"], name: "index_products_on_product_group_id", using: :btree

  create_table "purchases", force: :cascade do |t|
    t.integer  "contractor_id"
    t.integer  "store_id"
    t.datetime "date"
    t.integer  "status"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.text     "comment"
    t.boolean  "skip_revaluation"
  end

  add_index "purchases", ["contractor_id"], name: "index_purchases_on_contractor_id", using: :btree
  add_index "purchases", ["status"], name: "index_purchases_on_status", using: :btree
  add_index "purchases", ["store_id"], name: "index_purchases_on_store_id", using: :btree

  create_table "quick_orders", force: :cascade do |t|
    t.integer  "number"
    t.boolean  "is_done"
    t.integer  "user_id"
    t.string   "client_name",   limit: 255
    t.string   "contact_phone", limit: 255
    t.text     "comment"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "security_code", limit: 255
    t.integer  "department_id"
    t.string   "device_kind",   limit: 255
    t.integer  "client_id"
  end

  add_index "quick_orders", ["client_id"], name: "index_quick_orders_on_client_id", using: :btree
  add_index "quick_orders", ["client_name"], name: "index_quick_orders_on_client_name", using: :btree
  add_index "quick_orders", ["contact_phone"], name: "index_quick_orders_on_contact_phone", using: :btree
  add_index "quick_orders", ["department_id"], name: "index_quick_orders_on_department_id", using: :btree
  add_index "quick_orders", ["number"], name: "index_quick_orders_on_number", using: :btree
  add_index "quick_orders", ["user_id"], name: "index_quick_orders_on_user_id", using: :btree

  create_table "quick_orders_quick_tasks", id: false, force: :cascade do |t|
    t.integer "quick_order_id"
    t.integer "quick_task_id"
  end

  add_index "quick_orders_quick_tasks", ["quick_order_id", "quick_task_id"], name: "index_quick_orders_tasks", using: :btree

  create_table "quick_tasks", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "repair_groups", force: :cascade do |t|
    t.string   "name",           limit: 255
    t.string   "ancestry",       limit: 255
    t.integer  "ancestry_depth",             default: 0
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
  end

  add_index "repair_groups", ["ancestry"], name: "index_repair_groups_on_ancestry", using: :btree

  create_table "repair_parts", force: :cascade do |t|
    t.integer  "repair_task_id"
    t.integer  "item_id"
    t.integer  "quantity"
    t.integer  "warranty_term"
    t.integer  "defect_qty"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_index "repair_parts", ["item_id"], name: "index_repair_parts_on_item_id", using: :btree
  add_index "repair_parts", ["repair_task_id"], name: "index_repair_parts_on_repair_task_id", using: :btree

  create_table "repair_prices", force: :cascade do |t|
    t.integer  "repair_service_id"
    t.integer  "department_id"
    t.decimal  "value"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  add_index "repair_prices", ["department_id"], name: "index_repair_prices_on_department_id", using: :btree
  add_index "repair_prices", ["repair_service_id"], name: "index_repair_prices_on_repair_service_id", using: :btree

  create_table "repair_services", force: :cascade do |t|
    t.integer  "repair_group_id"
    t.string   "name",              limit: 255
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
    t.text     "client_info"
    t.boolean  "is_positive_price",             default: false
    t.boolean  "difficult",                     default: false
    t.boolean  "is_body_repair",                default: false
  end

  add_index "repair_services", ["repair_group_id"], name: "index_repair_services_on_repair_group_id", using: :btree

  create_table "repair_tasks", force: :cascade do |t|
    t.integer  "repair_service_id"
    t.integer  "device_task_id"
    t.decimal  "price"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
    t.integer  "store_id"
    t.integer  "repairer_id"
  end

  add_index "repair_tasks", ["device_task_id"], name: "index_repair_tasks_on_device_task_id", using: :btree
  add_index "repair_tasks", ["repair_service_id"], name: "index_repair_tasks_on_repair_service_id", using: :btree
  add_index "repair_tasks", ["repairer_id"], name: "index_repair_tasks_on_repairer_id", using: :btree
  add_index "repair_tasks", ["store_id"], name: "index_repair_tasks_on_store_id", using: :btree

  create_table "revaluation_acts", force: :cascade do |t|
    t.integer  "price_type_id"
    t.datetime "date"
    t.integer  "status"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "revaluation_acts", ["price_type_id"], name: "index_revaluation_acts_on_price_type_id", using: :btree
  add_index "revaluation_acts", ["status"], name: "index_revaluation_acts_on_status", using: :btree

  create_table "revaluations", force: :cascade do |t|
    t.integer  "revaluation_act_id"
    t.integer  "product_id"
    t.decimal  "price"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

  add_index "revaluations", ["product_id"], name: "index_revaluations_on_product_id", using: :btree
  add_index "revaluations", ["revaluation_act_id"], name: "index_revaluations_on_revaluation_act_id", using: :btree

  create_table "salaries", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "amount"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.datetime "issued_at"
    t.boolean  "is_prepayment"
  end

  add_index "salaries", ["is_prepayment"], name: "index_salaries_on_is_prepayment", using: :btree
  add_index "salaries", ["user_id"], name: "index_salaries_on_user_id", using: :btree

  create_table "sale_items", force: :cascade do |t|
    t.integer  "sale_id"
    t.integer  "item_id"
    t.decimal  "price",          precision: 8, scale: 2
    t.integer  "quantity"
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
    t.decimal  "discount",                               default: 0.0
    t.integer  "device_task_id"
  end

  add_index "sale_items", ["device_task_id"], name: "index_sale_items_on_device_task_id", using: :btree
  add_index "sale_items", ["item_id"], name: "index_sale_items_on_item_id", using: :btree
  add_index "sale_items", ["sale_id"], name: "index_sale_items_on_sale_id", using: :btree

  create_table "sales", force: :cascade do |t|
    t.integer  "store_id"
    t.integer  "user_id"
    t.integer  "client_id"
    t.datetime "date"
    t.integer  "status"
    t.boolean  "is_return"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.integer  "cash_shift_id"
  end

  add_index "sales", ["cash_shift_id"], name: "index_sales_on_cash_shift_id", using: :btree
  add_index "sales", ["client_id"], name: "index_sales_on_client_id", using: :btree
  add_index "sales", ["status"], name: "index_sales_on_status", using: :btree
  add_index "sales", ["store_id"], name: "index_sales_on_store_id", using: :btree
  add_index "sales", ["user_id"], name: "index_sales_on_user_id", using: :btree

  create_table "schedule_days", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "day"
    t.string   "hours",      limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "schedule_days", ["day"], name: "index_schedule_days_on_day", using: :btree
  add_index "schedule_days", ["user_id"], name: "index_schedule_days_on_user_id", using: :btree

  create_table "service_feedbacks", force: :cascade do |t|
    t.integer  "service_job_id",             null: false
    t.datetime "scheduled_on"
    t.integer  "postpone_count", default: 0, null: false
    t.text     "details"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.text     "log"
  end

  add_index "service_feedbacks", ["service_job_id"], name: "index_service_feedbacks_on_service_job_id", using: :btree

  create_table "service_free_jobs", force: :cascade do |t|
    t.integer  "performer_id",  null: false
    t.integer  "client_id",     null: false
    t.integer  "task_id",       null: false
    t.text     "comment"
    t.datetime "performed_at",  null: false
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.integer  "receiver_id"
    t.integer  "department_id", null: false
  end

  add_index "service_free_jobs", ["client_id"], name: "index_service_free_jobs_on_client_id", using: :btree
  add_index "service_free_jobs", ["department_id"], name: "index_service_free_jobs_on_department_id", using: :btree
  add_index "service_free_jobs", ["performer_id"], name: "index_service_free_jobs_on_performer_id", using: :btree
  add_index "service_free_jobs", ["receiver_id"], name: "index_service_free_jobs_on_receiver_id", using: :btree
  add_index "service_free_jobs", ["task_id"], name: "index_service_free_jobs_on_task_id", using: :btree

  create_table "service_free_tasks", force: :cascade do |t|
    t.string   "name",       null: false
    t.string   "icon"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string   "code"
  end

  create_table "service_job_subscriptions", id: false, force: :cascade do |t|
    t.integer "service_job_id", null: false
    t.integer "subscriber_id",  null: false
  end

  add_index "service_job_subscriptions", ["service_job_id", "subscriber_id"], name: "index_service_job_subscriptions", unique: true, using: :btree
  add_index "service_job_subscriptions", ["service_job_id"], name: "index_service_job_subscriptions_on_service_job_id", using: :btree
  add_index "service_job_subscriptions", ["subscriber_id"], name: "index_service_job_subscriptions_on_subscriber_id", using: :btree

  create_table "service_job_templates", force: :cascade do |t|
    t.string   "field_name"
    t.string   "content",    null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "service_job_templates", ["field_name"], name: "index_service_job_templates_on_field_name", using: :btree

  create_table "service_job_viewings", force: :cascade do |t|
    t.integer  "service_job_id", null: false
    t.integer  "user_id",        null: false
    t.datetime "time",           null: false
    t.string   "ip",             null: false
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_index "service_job_viewings", ["service_job_id"], name: "index_service_job_viewings_on_service_job_id", using: :btree
  add_index "service_job_viewings", ["time"], name: "index_service_job_viewings_on_time", using: :btree
  add_index "service_job_viewings", ["user_id"], name: "index_service_job_viewings_on_user_id", using: :btree

  create_table "service_jobs", force: :cascade do |t|
    t.integer  "device_type_id"
    t.string   "ticket_number",            limit: 255
    t.integer  "client_id"
    t.text     "comment"
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
    t.datetime "done_at"
    t.string   "serial_number",            limit: 255
    t.integer  "location_id"
    t.integer  "user_id"
    t.string   "security_code",            limit: 255
    t.string   "status",                   limit: 255
    t.string   "imei",                     limit: 255
    t.boolean  "replaced",                             default: false
    t.boolean  "notify_client",                        default: false
    t.boolean  "client_notified"
    t.datetime "return_at"
    t.string   "app_store_pass",           limit: 255
    t.text     "tech_notice"
    t.string   "contact_phone",            limit: 255
    t.integer  "item_id"
    t.integer  "sale_id"
    t.integer  "case_color_id"
    t.integer  "department_id"
    t.boolean  "is_tray_present"
    t.integer  "carrier_id"
    t.integer  "keeper_id"
    t.string   "data_storages"
    t.string   "email"
    t.string   "client_address"
    t.text     "claimed_defect"
    t.text     "device_condition"
    t.text     "client_comment"
    t.string   "estimated_cost_of_repair"
    t.string   "type_of_work"
    t.integer  "initial_department_id"
    t.string   "trademark"
    t.string   "completeness"
    t.string   "device_group"
  end

  add_index "service_jobs", ["carrier_id"], name: "index_service_jobs_on_carrier_id", using: :btree
  add_index "service_jobs", ["case_color_id"], name: "index_service_jobs_on_case_color_id", using: :btree
  add_index "service_jobs", ["client_id"], name: "index_service_jobs_on_client_id", using: :btree
  add_index "service_jobs", ["department_id"], name: "index_service_jobs_on_department_id", using: :btree
  add_index "service_jobs", ["device_type_id"], name: "index_service_jobs_on_device_type_id", using: :btree
  add_index "service_jobs", ["done_at"], name: "index_service_jobs_on_done_at", using: :btree
  add_index "service_jobs", ["imei"], name: "index_service_jobs_on_imei", using: :btree
  add_index "service_jobs", ["initial_department_id"], name: "index_service_jobs_on_initial_department_id", using: :btree
  add_index "service_jobs", ["item_id"], name: "index_service_jobs_on_item_id", using: :btree
  add_index "service_jobs", ["location_id"], name: "index_service_jobs_on_location_id", using: :btree
  add_index "service_jobs", ["sale_id"], name: "index_service_jobs_on_sale_id", using: :btree
  add_index "service_jobs", ["status"], name: "index_service_jobs_on_status", using: :btree
  add_index "service_jobs", ["ticket_number"], name: "index_service_jobs_on_ticket_number", using: :btree
  add_index "service_jobs", ["user_id"], name: "index_service_jobs_on_user_id", using: :btree

  create_table "service_repair_returns", force: :cascade do |t|
    t.integer  "service_job_id", null: false
    t.integer  "performer_id",   null: false
    t.datetime "performed_at",   null: false
  end

  add_index "service_repair_returns", ["performer_id"], name: "index_service_repair_returns_on_performer_id", using: :btree
  add_index "service_repair_returns", ["service_job_id"], name: "index_service_repair_returns_on_service_job_id", using: :btree

  create_table "service_sms_notifications", force: :cascade do |t|
    t.integer  "sender_id",    null: false
    t.datetime "sent_at",      null: false
    t.text     "message",      null: false
    t.string   "phone_number", null: false
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "service_sms_notifications", ["sender_id"], name: "index_service_sms_notifications_on_sender_id", using: :btree

  create_table "settings", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.string   "presentation",  limit: 255
    t.text     "value"
    t.string   "value_type",    limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.integer  "department_id"
  end

  add_index "settings", ["department_id"], name: "index_settings_on_department_id", using: :btree
  add_index "settings", ["name"], name: "index_settings_on_name", using: :btree

  create_table "spare_part_defects", force: :cascade do |t|
    t.integer  "item_id"
    t.integer  "contractor_id"
    t.integer  "qty",                            null: false
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.integer  "repair_part_id"
    t.boolean  "is_warranty",    default: false, null: false
  end

  add_index "spare_part_defects", ["contractor_id"], name: "index_spare_part_defects_on_contractor_id", using: :btree
  add_index "spare_part_defects", ["item_id"], name: "index_spare_part_defects_on_item_id", using: :btree
  add_index "spare_part_defects", ["repair_part_id"], name: "index_spare_part_defects_on_repair_part_id", using: :btree

  create_table "spare_parts", force: :cascade do |t|
    t.integer  "repair_service_id"
    t.integer  "product_id"
    t.integer  "quantity"
    t.integer  "warranty_term"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  add_index "spare_parts", ["product_id"], name: "index_spare_parts_on_product_id", using: :btree
  add_index "spare_parts", ["repair_service_id"], name: "index_spare_parts_on_repair_service_id", using: :btree

  create_table "stolen_phones", force: :cascade do |t|
    t.string   "imei",           limit: 255
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.string   "serial_number",  limit: 255
    t.integer  "client_id"
    t.text     "client_comment"
    t.integer  "item_id"
  end

  add_index "stolen_phones", ["client_id"], name: "index_stolen_phones_on_client_id", using: :btree
  add_index "stolen_phones", ["imei"], name: "index_stolen_phones_on_imei", using: :btree
  add_index "stolen_phones", ["item_id"], name: "index_stolen_phones_on_item_id", using: :btree
  add_index "stolen_phones", ["serial_number"], name: "index_stolen_phones_on_serial_number", using: :btree

  create_table "store_items", force: :cascade do |t|
    t.integer  "item_id"
    t.integer  "store_id"
    t.integer  "quantity",   default: 0
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "store_items", ["item_id"], name: "index_store_items_on_item_id", using: :btree
  add_index "store_items", ["store_id"], name: "index_store_items_on_store_id", using: :btree

  create_table "store_products", force: :cascade do |t|
    t.integer  "store_id"
    t.integer  "product_id"
    t.integer  "warning_quantity"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  add_index "store_products", ["product_id", "store_id"], name: "index_store_products_on_product_id_and_store_id", using: :btree
  add_index "store_products", ["product_id"], name: "index_store_products_on_product_id", using: :btree
  add_index "store_products", ["store_id"], name: "index_store_products_on_store_id", using: :btree

  create_table "stores", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "code",          limit: 255
    t.string   "kind",          limit: 255
    t.integer  "department_id"
    t.boolean  "hidden"
  end

  add_index "stores", ["code"], name: "index_stores_on_code", using: :btree
  add_index "stores", ["department_id"], name: "index_stores_on_department_id", using: :btree

  create_table "substitute_phones", force: :cascade do |t|
    t.integer  "item_id"
    t.text     "condition",      null: false
    t.integer  "service_job_id"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.integer  "department_id"
    t.boolean  "archived"
  end

  add_index "substitute_phones", ["department_id"], name: "index_substitute_phones_on_department_id", using: :btree
  add_index "substitute_phones", ["item_id"], name: "index_substitute_phones_on_item_id", using: :btree
  add_index "substitute_phones", ["service_job_id"], name: "index_substitute_phones_on_service_job_id", unique: true, using: :btree

  create_table "supplies", force: :cascade do |t|
    t.integer  "supply_report_id"
    t.integer  "supply_category_id"
    t.string   "name",               limit: 255
    t.integer  "quantity"
    t.decimal  "cost"
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
  end

  add_index "supplies", ["supply_category_id"], name: "index_supplies_on_supply_category_id", using: :btree
  add_index "supplies", ["supply_report_id"], name: "index_supplies_on_supply_report_id", using: :btree

  create_table "supply_categories", force: :cascade do |t|
    t.string   "name",       limit: 255
    t.string   "ancestry",   limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "supply_categories", ["ancestry"], name: "index_supply_categories_on_ancestry", using: :btree

  create_table "supply_reports", force: :cascade do |t|
    t.date     "date"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.integer  "department_id"
  end

  add_index "supply_reports", ["department_id"], name: "index_supply_reports_on_department_id", using: :btree

  create_table "supply_requests", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "status",        limit: 255
    t.string   "object",        limit: 255
    t.text     "description"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.integer  "department_id"
  end

  add_index "supply_requests", ["department_id"], name: "index_supply_requests_on_department_id", using: :btree
  add_index "supply_requests", ["status"], name: "index_supply_requests_on_status", using: :btree
  add_index "supply_requests", ["user_id"], name: "index_supply_requests_on_user_id", using: :btree

  create_table "task_templates", force: :cascade do |t|
    t.text     "content",    null: false
    t.string   "icon"
    t.string   "ancestry"
    t.integer  "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "task_templates", ["ancestry"], name: "index_task_templates_on_ancestry", using: :btree

  create_table "tasks", force: :cascade do |t|
    t.string   "name",          limit: 255
    t.integer  "duration"
    t.decimal  "cost"
    t.datetime "created_at",                                null: false
    t.datetime "updated_at",                                null: false
    t.integer  "priority",                  default: 0
    t.string   "role",          limit: 255
    t.integer  "product_id"
    t.boolean  "hidden",                    default: false
    t.string   "code"
    t.string   "location_code"
  end

  add_index "tasks", ["name"], name: "index_tasks_on_name", using: :btree
  add_index "tasks", ["product_id"], name: "index_tasks_on_product_id", using: :btree
  add_index "tasks", ["role"], name: "index_tasks_on_role", using: :btree

  create_table "timesheet_days", force: :cascade do |t|
    t.date     "date"
    t.integer  "user_id"
    t.string   "status",     limit: 255
    t.integer  "work_mins"
    t.time     "time"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "timesheet_days", ["date"], name: "index_timesheet_days_on_date", using: :btree
  add_index "timesheet_days", ["status"], name: "index_timesheet_days_on_status", using: :btree
  add_index "timesheet_days", ["user_id"], name: "index_timesheet_days_on_user_id", using: :btree

  create_table "top_salables", force: :cascade do |t|
    t.integer  "product_id"
    t.string   "name",       limit: 255
    t.string   "ancestry",   limit: 255
    t.integer  "position"
    t.string   "color",      limit: 255
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "top_salables", ["ancestry"], name: "index_top_salables_on_ancestry", using: :btree
  add_index "top_salables", ["product_id"], name: "index_top_salables_on_product_id", using: :btree

  create_table "trade_in_devices", force: :cascade do |t|
    t.integer  "number"
    t.datetime "received_at",                        null: false
    t.integer  "item_id",                            null: false
    t.integer  "receiver_id"
    t.integer  "appraised_value",                    null: false
    t.string   "appraiser",                          null: false
    t.string   "bought_device",                      null: false
    t.string   "client_name"
    t.string   "client_phone"
    t.string   "check_icloud",                       null: false
    t.integer  "replacement_status"
    t.boolean  "archived",           default: false, null: false
    t.text     "archiving_comment"
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.text     "condition"
    t.text     "equipment"
    t.date     "apple_guarantee"
    t.integer  "department_id",                      null: false
    t.boolean  "confirmed",          default: false, null: false
    t.boolean  "extended_guarantee"
    t.integer  "sale_amount"
    t.integer  "client_id"
  end

  add_index "trade_in_devices", ["client_id"], name: "index_trade_in_devices_on_client_id", using: :btree
  add_index "trade_in_devices", ["department_id"], name: "index_trade_in_devices_on_department_id", using: :btree
  add_index "trade_in_devices", ["item_id"], name: "index_trade_in_devices_on_item_id", using: :btree
  add_index "trade_in_devices", ["receiver_id"], name: "index_trade_in_devices_on_receiver_id", using: :btree

  create_table "users", force: :cascade do |t|
    t.string   "username",                  limit: 255
    t.string   "role",                      limit: 255
    t.datetime "created_at",                                            null: false
    t.datetime "updated_at",                                            null: false
    t.string   "encrypted_password",        limit: 255, default: "",    null: false
    t.string   "reset_password_token",      limit: 255
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",                         default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip",        limit: 255
    t.string   "last_sign_in_ip",           limit: 255
    t.string   "authentication_token",      limit: 255
    t.string   "email",                     limit: 255, default: ""
    t.integer  "location_id"
    t.string   "photo",                     limit: 255
    t.string   "surname",                   limit: 255
    t.string   "name",                      limit: 255
    t.string   "patronymic",                limit: 255
    t.date     "birthday"
    t.date     "hiring_date"
    t.date     "salary_date"
    t.string   "prepayment",                limit: 255
    t.text     "wish"
    t.string   "card_number",               limit: 255
    t.string   "color",                     limit: 255
    t.integer  "abilities_mask"
    t.boolean  "schedule"
    t.integer  "position"
    t.boolean  "is_fired"
    t.string   "job_title",                 limit: 255
    t.integer  "store_id"
    t.integer  "department_id"
    t.integer  "session_duration"
    t.string   "phone_number",              limit: 255
    t.boolean  "department_autochangeable",             default: true,  null: false
    t.boolean  "can_help_in_repair",                    default: false
    t.boolean  "can_help_in_mac_service",               default: false
  end

  add_index "users", ["authentication_token"], name: "index_users_on_authentication_token", unique: true, using: :btree
  add_index "users", ["card_number"], name: "index_users_on_card_number", using: :btree
  add_index "users", ["department_id"], name: "index_users_on_department_id", using: :btree
  add_index "users", ["email"], name: "index_users_on_email", using: :btree
  add_index "users", ["is_fired"], name: "index_users_on_is_fired", using: :btree
  add_index "users", ["job_title"], name: "index_users_on_job_title", using: :btree
  add_index "users", ["location_id"], name: "index_users_on_location_id", using: :btree
  add_index "users", ["name"], name: "index_users_on_name", using: :btree
  add_index "users", ["patronymic"], name: "index_users_on_patronymic", using: :btree
  add_index "users", ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true, using: :btree
  add_index "users", ["schedule"], name: "index_users_on_schedule", using: :btree
  add_index "users", ["store_id"], name: "index_users_on_store_id", using: :btree
  add_index "users", ["surname"], name: "index_users_on_surname", using: :btree
  add_index "users", ["username"], name: "index_users_on_username", using: :btree

  create_table "wiki_page_attachments", force: :cascade do |t|
    t.integer  "page_id",                                       null: false
    t.string   "wiki_page_attachment_file_name",    limit: 255
    t.string   "wiki_page_attachment_content_type", limit: 255
    t.integer  "wiki_page_attachment_file_size"
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
  end

  create_table "wiki_page_versions", force: :cascade do |t|
    t.integer  "page_id",                null: false
    t.integer  "updator_id"
    t.integer  "number"
    t.string   "comment",    limit: 255
    t.string   "path",       limit: 255
    t.string   "title",      limit: 255
    t.text     "content"
    t.datetime "updated_at"
  end

  add_index "wiki_page_versions", ["page_id"], name: "index_wiki_page_versions_on_page_id", using: :btree
  add_index "wiki_page_versions", ["updator_id"], name: "index_wiki_page_versions_on_updator_id", using: :btree

  create_table "wiki_pages", force: :cascade do |t|
    t.integer  "creator_id"
    t.integer  "updator_id"
    t.string   "path",       limit: 255
    t.string   "title",      limit: 255
    t.text     "content"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "wiki_pages", ["creator_id"], name: "index_wiki_pages_on_creator_id", using: :btree
  add_index "wiki_pages", ["path"], name: "index_wiki_pages_on_path", unique: true, using: :btree

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
