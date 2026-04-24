# Backroom Job Activity

`backroom` provides reusable ActiveRecord progress tracking for Rails admin screens, background jobs, and operational dashboards. It stores one progress row per owner, job class, and run id, then leaves host applications in charge of associations, authorization, presentation, broadcasting, and concrete job workflows.

## Installation

Use the local path while this gem is still private:

```ruby
gem "backroom", path: "../backroom"
```

Then include the concern in a host model that owns its table and app-specific associations:

```ruby
class TenantJobProgress < ApplicationRecord
  include Backroom::JobActivity::ProgressRecord

  belongs_to :account

  self.job_activity_after_commit = lambda do |progress|
    Admin::JobActivityBroadcaster.broadcast(progress)
  end
end
```

## Required Table Shape

The host app should provide a table like this. The table and model names are intentionally app-owned for now.

```ruby
create_table :tenant_job_progresses do |t|
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

add_index :tenant_job_progresses,
  [ :account_id, :job_class_name, :run_id ],
  unique: true,
  name: "index_tenant_job_progresses_on_account_job_run"
add_index :tenant_job_progresses,
  [ :account_id, :job_class_name, :started_at ],
  name: "index_tenant_job_progresses_on_account_job_started"
```

## API

`Backroom::JobActivity::ProgressRecord` adds:

- status constants: `ACTIVE_STATUSES` and `FINAL_STATUSES`
- validations for required identity fields, status, percent, and non-negative counters
- scopes: `recent_first`, `active`, and `for_run(account_id:, job_class_name:, run_id:)`
- `.track!` upsert semantics keyed by `account_id`, `job_class_name`, and `run_id`
- count normalization and percent calculation
- queued/scheduled timestamp preservation through `metadata["queued_at"]`
- `#active?`
- configurable `self.job_activity_after_commit = ->(record) { ... }`

Example:

```ruby
TenantJobProgress.track!(
  account_id: account.id,
  job_class_name: ImportCustomersJob.name,
  run_id: run_id,
  status: "running",
  phase: "Importing customers",
  total: 100,
  completed: 25,
  metadata: { label: "Customer import" }
)
```

## Development

```sh
bundle install
bundle exec rspec
bundle exec rake
```

## Extraction Boundary

Keep these in the host app until they prove reusable:

- admin activity snapshots, controllers, helpers, and views
- broadcaster audiences and Turbo stream targets
- account ownership associations and authorization
- job labels, queue names, recovery arguments, and cancellation UI
- concrete job classes such as imports, exports, syncs, report generation, and data repair jobs

Planned next steps are a Rails install generator, configuration for table/model naming, and optional generic cancellation helpers after the progress model API stabilizes.
