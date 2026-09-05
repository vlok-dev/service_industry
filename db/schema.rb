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

ActiveRecord::Schema[8.1].define(version: 2026_09_05_203000) do
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

  create_table "inventory_items", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.string "unit"
    t.decimal "unit_price", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_inventory_items_on_code", unique: true
  end

  create_table "jobs", force: :cascade do |t|
    t.text "address"
    t.integer "assigned_to_id"
    t.datetime "cancelled_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "customer_name"
    t.text "description"
    t.string "invoice_number"
    t.boolean "is_project", default: false, null: false
    t.string "job_number"
    t.text "notes"
    t.integer "priority"
    t.date "scheduled_date"
    t.date "scheduled_end_date"
    t.time "scheduled_time"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["assigned_to_id"], name: "index_jobs_on_assigned_to_id"
    t.index ["is_project"], name: "index_jobs_on_is_project"
    t.index ["user_id"], name: "index_jobs_on_user_id"
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
    t.integer "quantity"
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

  create_table "settings", force: :cascade do |t|
    t.string "company_name"
    t.datetime "created_at", null: false
    t.string "default_job_priority"
    t.string "notification_email"
    t.datetime "updated_at", null: false
    t.string "whatsapp_api_key"
    t.string "whatsapp_phone_id"
    t.time "working_hours_end"
    t.time "working_hours_start"
  end

  create_table "suppliers", force: :cascade do |t|
    t.text "address"
    t.string "contact_person"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name", null: false
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_suppliers_on_name"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.string "phone_number"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "claims", "jobs"
  add_foreign_key "jobs", "users"
  add_foreign_key "jobs", "users", column: "assigned_to_id"
  add_foreign_key "purchase_order_items", "inventory_items"
  add_foreign_key "purchase_order_items", "purchase_orders"
  add_foreign_key "purchase_orders", "jobs"
  add_foreign_key "purchase_orders", "suppliers"
  add_foreign_key "purchase_orders", "users", column: "created_by_id"
end
