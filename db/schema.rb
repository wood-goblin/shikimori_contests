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
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 20130630132518) do
  create_table "contest_links", :force => true do |t|
    t.integer  "contest_id"
    t.integer  "linked_id"
    t.string   "linked_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "contest_links", ["linked_id", "linked_type", "contest_id"], :name => "index_contest_links_on_linked_id_and_linked_type_and_contest_id"

  create_table "contest_matches", :force => true do |t|
    t.integer  "round_id"
    t.string   "state",       :default => "created"
    t.string   "group"
    t.integer  "left_id"
    t.string   "left_type"
    t.integer  "right_id"
    t.string   "right_type"
    t.date     "started_on"
    t.date     "finished_on"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "winner_id"
  end

  add_index "contest_matches", ["round_id"], :name => "index_contest_votes_on_contest_round_id"

  create_table "contest_rounds", :force => true do |t|
    t.integer  "contest_id"
    t.string   "state",      :default => "created"
    t.integer  "number"
    t.boolean  "additional"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "contest_rounds", ["contest_id"], :name => "index_contest_rounds_on_contest_id"

  create_table "contest_suggestions", :force => true do |t|
    t.integer  "contest_id"
    t.integer  "user_id"
    t.integer  "item_id"
    t.string   "item_type"
    t.datetime "created_at", :null => false
    t.datetime "updated_at", :null => false
  end

  add_index "contest_suggestions", ["contest_id"], :name => "index_contest_suggestions_on_contest_id"
  add_index "contest_suggestions", ["item_id"], :name => "index_contest_suggestions_on_item_id"
  add_index "contest_suggestions", ["user_id"], :name => "index_contest_suggestions_on_user_id"

  create_table "contest_user_votes", :force => true do |t|
    t.integer "contest_match_id", :null => false
    t.integer "user_id",          :null => false
    t.integer "item_id",          :null => false
    t.string  "ip",               :null => false
  end

  add_index "contest_user_votes", ["contest_match_id", "ip"], :name => "index_contest_user_votes_on_contest_vote_id_and_ip", :unique => true
  add_index "contest_user_votes", ["contest_match_id", "item_id"], :name => "index_contest_user_votes_on_contest_vote_id_and_item_id"
  add_index "contest_user_votes", ["contest_match_id", "user_id"], :name => "index_contest_user_votes_on_contest_vote_id_and_user_id", :unique => true
  add_index "contest_user_votes", ["contest_match_id"], :name => "index_contest_user_votes_on_contest_vote_id"

  create_table "contests", :force => true do |t|
    t.string   "title"
    t.text     "description"
    t.integer  "user_id"
    t.string   "state",                :default => "created"
    t.date     "started_on"
    t.integer  "matches_per_round"
    t.integer  "match_duration"
    t.integer  "matches_interval"
    t.integer  "wave_days"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "permalink"
    t.date     "finished_on"
    t.string   "user_vote_key"
    t.string   "strategy_type",        :default => "double_elimination", :null => false
    t.integer  "suggestions_per_user"
    t.string   "member_type",          :default => "anime"
  end

  add_index "contests", ["updated_at"], :name => "index_contests_on_updated_at"
end
