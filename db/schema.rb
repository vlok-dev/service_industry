# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_01_212656) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "addresses", force: :cascade do |t|
    t.text "address"
    t.bigint "client_id", null: false
    t.datetime "created_at", null: false
    t.boolean "is_default", default: false
    t.string "label", default: "Other"
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_addresses_on_client_id"
  end

  create_table "claims", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.date "claim_date", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "job_id", null: false
    t.string "reference"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_claims_on_job_id"
    t.index ["status"], name: "index_claims_on_status"
  end

  create_table "clients", force: :cascade do |t|
    t.text "address"
    t.string "company"
    t.string "contact_person"
    t.datetime "created_at", null: false
    t.string "customer_code"
    t.text "delivery_address"
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.string "name", null: false
    t.string "phone_number"
    t.text "postal_address"
    t.string "primary_contact_mobile"
    t.datetime "updated_at", null: false
    t.index ["customer_code"], name: "index_clients_on_customer_code"
    t.index ["name"], name: "index_clients_on_name"
  end

  create_table "digital_job_card_materials", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "digital_job_card_id", null: false
    t.decimal "hours_worked", default: "1.0", null: false
    t.bigint "inventory_item_id"
    t.boolean "is_labor", default: false
    t.decimal "labor_rate", precision: 10, scale: 2, default: "0.0"
    t.decimal "markup", precision: 5, scale: 2, default: "0.0"
    t.string "material_name"
    t.decimal "quantity", precision: 10, scale: 4, default: "0.0"
    t.decimal "total_price", precision: 10, scale: 2, default: "0.0"
    t.decimal "unit_price", precision: 10, scale: 2, default: "0.0"
    t.datetime "updated_at", null: false
    t.index ["digital_job_card_id"], name: "index_digital_job_card_materials_on_digital_job_card_id"
    t.index ["inventory_item_id"], name: "index_digital_job_card_materials_on_inventory_item_id"
  end

  create_table "digital_job_cards", force: :cascade do |t|
    t.text "address"
    t.integer "client_id"
    t.string "client_name"
    t.datetime "created_at", null: false
    t.date "date"
    t.text "description"
    t.bigint "job_id"
    t.time "time_finish"
    t.time "time_start"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["client_id"], name: "index_digital_job_cards_on_client_id"
    t.index ["job_id"], name: "index_digital_job_cards_on_job_id"
    t.index ["user_id"], name: "index_digital_job_cards_on_user_id"
  end

  create_table "inventory_items", force: :cascade do |t|
    t.string "code", null: false
    t.decimal "cost_price", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.string "created_by"
    t.text "description"
    t.boolean "is_active", default: true, null: false
    t.boolean "is_quantity_tracked", default: true, null: false
    t.boolean "is_serializable", default: false, null: false
    t.decimal "list_price", precision: 10, scale: 2
    t.string "modified_by"
    t.string "name", null: false
    t.decimal "replacement_percentage", precision: 5, scale: 2
    t.string "stock_item_type"
    t.decimal "total_stock_quantity", precision: 12, scale: 2, default: "0.0"
    t.string "unit"
    t.decimal "unit_price", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_inventory_items_on_code", unique: true
    t.index ["is_active"], name: "index_inventory_items_on_is_active"
  end

  create_table "jobs", force: :cascade do |t|
    t.text "address"
    t.integer "assigned_to_id"
    t.datetime "cancelled_at"
    t.integer "client_id"
    t.datetime "completed_at"
    t.string "contact_number"
    t.string "contact_person"
    t.datetime "created_at", null: false
    t.string "customer_code"
    t.string "customer_name"
    t.text "description"
    t.string "email"
    t.string "invoice_number"
    t.boolean "is_project", default: false, null: false
    t.string "job_number"
    t.text "notes"
    t.text "postal_address"
    t.integer "priority"
    t.date "scheduled_date"
    t.date "scheduled_end_date"
    t.time "scheduled_time"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.datetime "whatsapp_sent_at"
    t.index ["assigned_to_id"], name: "index_jobs_on_assigned_to_id"
    t.index ["client_id"], name: "index_jobs_on_client_id"
    t.index ["is_project"], name: "index_jobs_on_is_project"
    t.index ["user_id"], name: "index_jobs_on_user_id"
  end

  create_table "people", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "phone_number"
    t.datetime "updated_at", null: false
  end

  create_table "planner_entries", force: :cascade do |t|
    t.bigint "assigned_to_id"
    t.string "category", default: "other"
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description"
    t.date "entry_date", null: false
    t.time "entry_time"
    t.text "notes"
    t.string "status", default: "to_do"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.datetime "whatsapp_sent_at"
    t.index ["assigned_to_id"], name: "index_planner_entries_on_assigned_to_id"
    t.index ["category"], name: "index_planner_entries_on_category"
    t.index ["created_by_id"], name: "index_planner_entries_on_created_by_id"
    t.index ["entry_date"], name: "index_planner_entries_on_entry_date"
    t.index ["status"], name: "index_planner_entries_on_status"
  end

  create_table "posts", force: :cascade do |t|
    t.text "author"
    t.text "body"
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "purchase_order_items", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.string "description"
    t.integer "inventory_item_id"
    t.integer "purchase_order_id", null: false
    t.decimal "quantity", precision: 12, scale: 4
    t.decimal "total"
    t.decimal "unit_price"
    t.datetime "updated_at", null: false
    t.index ["inventory_item_id"], name: "index_purchase_order_items_on_inventory_item_id"
    t.index ["purchase_order_id"], name: "index_purchase_order_items_on_purchase_order_id"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_by_id", null: false
    t.date "expected_delivery"
    t.integer "job_id", null: false
    t.text "notes"
    t.date "order_date"
    t.string "po_number"
    t.string "supplier_contact"
    t.integer "supplier_id"
    t.string "supplier_name"
    t.decimal "total_amount"
    t.datetime "updated_at", null: false
    t.decimal "vat_rate", precision: 5, scale: 2, default: "15.0", null: false
    t.index ["created_by_id"], name: "index_purchase_orders_on_created_by_id"
    t.index ["job_id"], name: "index_purchase_orders_on_job_id"
    t.index ["supplier_id"], name: "index_purchase_orders_on_supplier_id"
  end
