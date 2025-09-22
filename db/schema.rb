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

ActiveRecord::Schema[8.0].define(version: 2025_09_22_174335) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "agent_executions", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.bigint "user_id"
    t.string "status"
    t.text "input"
    t.text "output"
    t.integer "execution_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id"], name: "index_agent_executions_on_agent_id"
    t.index ["user_id"], name: "index_agent_executions_on_user_id"
  end

  create_table "agents", force: :cascade do |t|
    t.string "name"
    t.string "agent_type"
    t.string "status"
    t.text "capabilities"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "epics", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "status"
    t.string "priority"
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_epics_on_project_id"
  end

  create_table "prds", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.string "status"
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_prds_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "status"
    t.bigint "owner_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_projects_on_owner_id"
  end

  create_table "roadmaps", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_roadmaps_on_project_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "status"
    t.string "priority"
    t.bigint "assignee_id"
    t.bigint "epic_id", null: false
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_tasks_on_assignee_id"
    t.index ["epic_id"], name: "index_tasks_on_epic_id"
    t.index ["project_id"], name: "index_tasks_on_project_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "password_digest"
    t.string "role"
    t.text "integration_tokens"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slack_user_id"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "agent_executions", "agents"
  add_foreign_key "agent_executions", "users"
  add_foreign_key "epics", "projects"
  add_foreign_key "prds", "projects"
  add_foreign_key "projects", "users", column: "owner_id"
  add_foreign_key "roadmaps", "projects"
  add_foreign_key "tasks", "epics"
  add_foreign_key "tasks", "projects"
  add_foreign_key "tasks", "users", column: "assignee_id"
end
