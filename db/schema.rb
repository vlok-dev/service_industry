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

ActiveRecord::Schema[8.1].define(version: 2026_09_03_161919) do
  create_table "jobs", force: :cascade do |t|
    t.text "address"
    t.integer "assigned_to_id"
    t.datetime "cancelled_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "customer_name"
    t.text "description"
    t.string "invoice_number"
    t.string "job_number"
    t.text "notes"
    t.integer "priority"
    t.date "scheduled_date"
    t.time "scheduled_time"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["assigned_to_id"], name: "index_jobs_on_assigned_to_id"
    t.index ["user_id"], name: "index_jobs_on_user_id"
  end

  create_table "posts", force: :cascade do |t|
    t.text "author"
    t.text "body"
    t.datetime "created_at", null: false
    t.string "title"
    t.datetime "updated_at", null: false
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

  add_foreign_key "jobs", "users"
  add_foreign_key "jobs", "users", column: "assigned_to_id"
end
