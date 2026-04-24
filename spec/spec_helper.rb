# frozen_string_literal: true

require "bundler/setup"
require "active_record"
require "backroom/job_activity"
require "tmpdir"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :job_progress_records, force: true do |t|
    t.integer :account_id, null: false
    t.string :job_class_name, null: false
    t.string :run_id, null: false
    t.string :status, null: false, default: "running"
    t.string :phase
    t.integer :total, null: false, default: 0
    t.integer :completed, null: false, default: 0
    t.integer :skipped, null: false, default: 0
    t.integer :failed, null: false, default: 0
    t.integer :percent, null: false, default: 0
    t.json :metadata, null: false, default: {}
    t.datetime :started_at, null: false
    t.datetime :finished_at

    t.timestamps
  end

  add_index :job_progress_records,
    [ :account_id, :job_class_name, :run_id ],
    unique: true,
    name: "index_job_progress_records_on_account_job_run"
  add_index :job_progress_records,
    [ :account_id, :job_class_name, :started_at ],
    name: "index_job_progress_records_on_account_job_started"

  create_table :tenant_job_progresses, force: true do |t|
    t.integer :tenant_id, null: false
    t.string :job_class_name, null: false
    t.string :run_id, null: false
    t.string :status, null: false, default: "running"
    t.string :phase
    t.integer :total, null: false, default: 0
    t.integer :completed, null: false, default: 0
    t.integer :skipped, null: false, default: 0
    t.integer :failed, null: false, default: 0
    t.integer :percent, null: false, default: 0
    t.json :metadata, null: false, default: {}
    t.datetime :started_at, null: false
    t.datetime :finished_at

    t.timestamps
  end

  add_index :tenant_job_progresses,
    [ :tenant_id, :job_class_name, :run_id ],
    unique: true,
    name: "index_tenant_job_progresses_on_tenant_job_run"
  add_index :tenant_job_progresses,
    [ :tenant_id, :job_class_name, :started_at ],
    name: "index_tenant_job_progresses_on_tenant_job_started"
end

class JobProgressRecord < ActiveRecord::Base
  include Backroom::JobActivity::ProgressRecord
end

Backroom::JobActivity.configure do |config|
  config.owner_key = :tenant_id
  config.default_table_name = :tenant_job_progresses
end

class TenantJobProgress < ActiveRecord::Base
  include Backroom::JobActivity::ProgressRecord
end

Backroom::JobActivity.configure do |config|
  config.owner_key = :account_id
  config.default_table_name = :job_progress_records
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.before do
    JobProgressRecord.delete_all
    JobProgressRecord.job_activity_after_commit = nil
    TenantJobProgress.delete_all
    TenantJobProgress.job_activity_after_commit = nil
  end
end
