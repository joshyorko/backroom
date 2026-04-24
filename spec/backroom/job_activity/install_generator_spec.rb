# frozen_string_literal: true

require "spec_helper"
require "rails/generators"
require "generators/backroom/job_activity/install_generator"

RSpec.describe Backroom::JobActivity::Generators::InstallGenerator do
  around do |example|
    Dir.mktmpdir do |dir|
      @destination_root = dir
      example.run
    end
  end

  def run_generator(*arguments)
    described_class.start(arguments, destination_root: @destination_root)
  end

  def generated_file(path_pattern)
    Dir[File.join(@destination_root, path_pattern)].first
  end

  it "generates the default model and migration" do
    run_generator

    model_path = File.join(@destination_root, "app/models/job_progress_record.rb")
    migration_path = generated_file("db/migrate/*_create_job_progress_records.rb")

    expect(File.read(model_path)).to include("class JobProgressRecord < ApplicationRecord")
    expect(File.read(model_path)).to include("include Backroom::JobActivity::ProgressRecord")
    expect(File.read(migration_path)).to include("create_table :job_progress_records")
    expect(File.read(migration_path)).to include("t.integer :account_id, null: false")
  end

  it "accepts custom model, table, and owner key names" do
    run_generator("TenantJobProgress", "--table_name=tenant_job_progresses", "--owner_key=tenant_id")

    model_path = File.join(@destination_root, "app/models/tenant_job_progress.rb")
    migration_path = generated_file("db/migrate/*_create_tenant_job_progresses.rb")

    expect(File.read(model_path)).to include("class TenantJobProgress < ApplicationRecord")
    expect(File.read(model_path)).to include("belongs_to :tenant")
    expect(File.read(migration_path)).to include("create_table :tenant_job_progresses")
    expect(File.read(migration_path)).to include("t.integer :tenant_id, null: false")
    expect(File.read(migration_path)).to include("index_tenant_job_progresses_on_tenant_id_job_run")
  end

  it "shortens generated index names for long identifiers" do
    run_generator(
      "TenantScopedBackroomProgressRecord",
      "--table_name=tenant_scoped_backroom_progress_records",
      "--owner_key=organization_account_id"
    )

    migration_path = generated_file("db/migrate/*_create_tenant_scoped_backroom_progress_records.rb")
    index_names = File.read(migration_path).scan(/name: "([^"]+)"/).flatten

    expect(index_names).to all(satisfy { |name| name.length <= 63 })
  end
end
