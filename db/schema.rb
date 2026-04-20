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

ActiveRecord::Schema[7.1].define(version: 2026_04_20_232958) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "vector"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "llm_preferences", default: {}, null: false
    t.jsonb "media_generation_preferences", default: {}, null: false
  end

  create_table "analyses", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "competitor_id", null: false
    t.integer "status", default: 0, null: false
    t.string "scraping_provider"
    t.string "scraping_run_id"
    t.jsonb "raw_data", default: {}, null: false
    t.jsonb "profile_metrics", default: {}, null: false
    t.jsonb "insights", default: {}, null: false
    t.integer "posts_scraped_count", default: 0, null: false
    t.integer "posts_analyzed_count", default: 0, null: false
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "max_posts", default: 50, null: false
    t.index ["account_id", "created_at"], name: "index_analyses_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_analyses_on_account_id"
    t.index ["competitor_id"], name: "index_analyses_on_competitor_id"
    t.index ["status"], name: "index_analyses_on_status"
  end

  create_table "analysis_playbooks", force: :cascade do |t|
    t.bigint "analysis_id", null: false
    t.bigint "playbook_id", null: false
    t.integer "update_status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_id", "playbook_id"], name: "index_analysis_playbooks_on_analysis_id_and_playbook_id", unique: true
    t.index ["analysis_id"], name: "index_analysis_playbooks_on_analysis_id"
    t.index ["playbook_id"], name: "index_analysis_playbooks_on_playbook_id"
  end

  create_table "api_credentials", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "provider", null: false
    t.string "encrypted_api_key", null: false
    t.boolean "active", default: true, null: false
    t.datetime "last_validated_at"
    t.integer "last_validation_status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "provider"], name: "index_api_credentials_on_account_id_and_provider", unique: true
    t.index ["account_id"], name: "index_api_credentials_on_account_id"
  end

  create_table "competitors", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "instagram_handle", null: false
    t.string "full_name"
    t.text "bio"
    t.integer "followers_count"
    t.integer "following_count"
    t.integer "posts_count"
    t.string "profile_pic_url"
    t.datetime "last_scraped_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "instagram_handle"], name: "index_competitors_on_account_id_and_instagram_handle", unique: true
    t.index ["account_id"], name: "index_competitors_on_account_id"
  end

  create_table "content_suggestions", force: :cascade do |t|
    t.bigint "analysis_id", null: false
    t.bigint "account_id", null: false
    t.integer "position", null: false
    t.integer "content_type", null: false
    t.string "hook"
    t.text "caption_draft"
    t.jsonb "format_details", default: {}, null: false
    t.string "suggested_hashtags", default: [], null: false, array: true
    t.text "rationale"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_content_suggestions_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_content_suggestions_on_account_id"
    t.index ["analysis_id", "content_type"], name: "index_content_suggestions_on_analysis_id_and_content_type"
    t.index ["analysis_id", "position"], name: "index_content_suggestions_on_analysis_id_and_position", unique: true
    t.index ["analysis_id"], name: "index_content_suggestions_on_analysis_id"
  end

  create_table "generated_medias", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "content_suggestion_id", null: false
    t.string "provider", default: "heygen", null: false
    t.integer "media_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.text "prompt_sent"
    t.jsonb "provider_params", default: {}
    t.string "provider_job_id"
    t.string "output_url"
    t.integer "duration_seconds"
    t.integer "cost_cents"
    t.text "error_message"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_generated_medias_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_generated_medias_on_account_id"
    t.index ["content_suggestion_id"], name: "index_generated_medias_on_content_suggestion_id"
    t.index ["provider_job_id"], name: "index_generated_medias_on_provider_job_id"
    t.index ["status"], name: "index_generated_medias_on_status"
  end

  create_table "llm_usage_logs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "analysis_id"
    t.string "provider", null: false
    t.string "model", null: false
    t.string "use_case"
    t.integer "prompt_tokens"
    t.integer "completion_tokens"
    t.integer "cost_cents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_llm_usage_logs_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_llm_usage_logs_on_account_id"
    t.index ["analysis_id"], name: "index_llm_usage_logs_on_analysis_id"
  end

  create_table "media_generation_usage_logs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "generated_media_id", null: false
    t.string "provider", null: false
    t.integer "duration_seconds"
    t.integer "cost_cents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_media_generation_usage_logs_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_media_generation_usage_logs_on_account_id"
    t.index ["generated_media_id"], name: "index_media_generation_usage_logs_on_generated_media_id"
  end

  create_table "playbook_feedbacks", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "playbook_id", null: false
    t.text "content", null: false
    t.string "source", null: false
    t.integer "status", default: 0, null: false
    t.bigint "incorporated_in_version_id"
    t.bigint "related_analysis_id"
    t.integer "related_own_post_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_playbook_feedbacks_on_account_id"
    t.index ["incorporated_in_version_id"], name: "index_playbook_feedbacks_on_incorporated_in_version_id"
    t.index ["playbook_id", "status"], name: "index_playbook_feedbacks_on_playbook_id_and_status"
    t.index ["playbook_id"], name: "index_playbook_feedbacks_on_playbook_id"
    t.index ["related_analysis_id"], name: "index_playbook_feedbacks_on_related_analysis_id"
  end

  create_table "playbook_versions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "playbook_id", null: false
    t.integer "version_number", null: false
    t.text "content", null: false
    t.text "diff_summary"
    t.bigint "triggered_by_analysis_id"
    t.bigint "incorporated_in_version_id"
    t.integer "feedbacks_incorporated_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_playbook_versions_on_account_id"
    t.index ["incorporated_in_version_id"], name: "index_playbook_versions_on_incorporated_in_version_id"
    t.index ["playbook_id", "version_number"], name: "index_playbook_versions_on_playbook_id_and_version_number", unique: true
    t.index ["playbook_id"], name: "index_playbook_versions_on_playbook_id"
    t.index ["triggered_by_analysis_id"], name: "index_playbook_versions_on_triggered_by_analysis_id"
  end

  create_table "playbooks", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "niche"
    t.text "purpose"
    t.integer "current_version_number", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_playbooks_on_account_id_and_name", unique: true
    t.index ["account_id"], name: "index_playbooks_on_account_id"
  end

  create_table "posts", force: :cascade do |t|
    t.bigint "analysis_id", null: false
    t.bigint "competitor_id", null: false
    t.bigint "account_id", null: false
    t.string "instagram_post_id", null: false
    t.string "shortcode"
    t.integer "post_type", null: false
    t.text "caption"
    t.string "display_url"
    t.string "video_url"
    t.integer "likes_count", default: 0, null: false
    t.integer "comments_count", default: 0, null: false
    t.integer "video_view_count"
    t.string "hashtags", default: [], null: false, array: true
    t.string "mentions", default: [], null: false, array: true
    t.datetime "posted_at"
    t.decimal "quality_score", precision: 10, scale: 4
    t.boolean "selected_for_analysis", default: false, null: false
    t.text "transcript"
    t.integer "transcript_status", default: 0, null: false
    t.datetime "transcribed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "posted_at"], name: "index_posts_on_account_id_and_posted_at"
    t.index ["account_id"], name: "index_posts_on_account_id"
    t.index ["analysis_id", "post_type", "quality_score"], name: "index_posts_on_analysis_id_and_post_type_and_quality_score"
    t.index ["analysis_id", "selected_for_analysis"], name: "index_posts_on_analysis_id_and_selected_for_analysis"
    t.index ["analysis_id"], name: "index_posts_on_analysis_id"
    t.index ["competitor_id"], name: "index_posts_on_competitor_id"
    t.index ["instagram_post_id"], name: "index_posts_on_instagram_post_id"
  end

  create_table "transcription_usage_logs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "post_id"
    t.bigint "analysis_id"
    t.string "provider", null: false
    t.string "model", null: false
    t.integer "audio_duration_seconds"
    t.integer "cost_cents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "created_at"], name: "index_transcription_usage_logs_on_account_id_and_created_at"
    t.index ["account_id"], name: "index_transcription_usage_logs_on_account_id"
    t.index ["analysis_id"], name: "index_transcription_usage_logs_on_analysis_id"
    t.index ["post_id"], name: "index_transcription_usage_logs_on_post_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "first_name"
    t.string "last_name"
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_users_on_account_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "analyses", "accounts"
  add_foreign_key "analyses", "competitors"
  add_foreign_key "analysis_playbooks", "analyses"
  add_foreign_key "analysis_playbooks", "playbooks"
  add_foreign_key "api_credentials", "accounts"
  add_foreign_key "competitors", "accounts"
  add_foreign_key "content_suggestions", "accounts"
  add_foreign_key "content_suggestions", "analyses"
  add_foreign_key "generated_medias", "accounts"
  add_foreign_key "generated_medias", "content_suggestions"
  add_foreign_key "llm_usage_logs", "accounts"
  add_foreign_key "llm_usage_logs", "analyses"
  add_foreign_key "media_generation_usage_logs", "accounts"
  add_foreign_key "media_generation_usage_logs", "generated_medias"
  add_foreign_key "playbook_feedbacks", "accounts"
  add_foreign_key "playbook_feedbacks", "analyses", column: "related_analysis_id"
  add_foreign_key "playbook_feedbacks", "playbook_versions", column: "incorporated_in_version_id"
  add_foreign_key "playbook_feedbacks", "playbooks"
  add_foreign_key "playbook_versions", "accounts"
  add_foreign_key "playbook_versions", "analyses", column: "triggered_by_analysis_id"
  add_foreign_key "playbook_versions", "playbook_versions", column: "incorporated_in_version_id"
  add_foreign_key "playbook_versions", "playbooks"
  add_foreign_key "playbooks", "accounts"
  add_foreign_key "posts", "accounts"
  add_foreign_key "posts", "analyses"
  add_foreign_key "posts", "competitors"
  add_foreign_key "transcription_usage_logs", "accounts"
  add_foreign_key "transcription_usage_logs", "analyses"
  add_foreign_key "transcription_usage_logs", "posts"
  add_foreign_key "users", "accounts"
end
