# frozen_string_literal: true

require "spec_helper"

RSpec.describe Backroom::JobActivity::ProgressRecord do
  describe ".track!" do
    it "creates a progress record keyed by account, job class, and run id" do
      record = JobProgressRecord.track!(
        account_id: 123,
        job_class_name: :DownloadTranscriptsJob,
        run_id: 456,
        status: "running",
        phase: "Downloading",
        total: 10,
        completed: 3,
        skipped: -4,
        failed: 1,
        metadata: { label: "Download" }
      )

      expect(record).to be_persisted
      expect(record.job_class_name).to eq("DownloadTranscriptsJob")
      expect(record.run_id).to eq("456")
      expect(record.percent).to eq(30)
      expect(record.skipped).to eq(0)
      expect(record.metadata).to include("label" => "Download")
    end

    it "updates the existing run and merges metadata" do
      JobProgressRecord.track!(
        account_id: 1,
        job_class_name: "ExtractIntentsJob",
        run_id: "abc",
        status: "running",
        total: 4,
        completed: 1,
        metadata: { first: true }
      )

      record = JobProgressRecord.track!(
        account_id: 1,
        job_class_name: "ExtractIntentsJob",
        run_id: "abc",
        completed: 4,
        metadata: { second: true }
      )

      expect(JobProgressRecord.count).to eq(1)
      expect(record.percent).to eq(100)
      expect(record.metadata).to include("first" => true, "second" => true)
    end

    it "records queued timestamps and preserves them when a job starts running" do
      queued_at = Time.utc(2026, 2, 24, 12, 0, 0)
      running_at = Time.utc(2026, 2, 24, 12, 5, 0)

      queued = JobProgressRecord.track!(
        account_id: 1,
        job_class_name: "DownloadTranscriptsJob",
        run_id: "run-1",
        status: "queued",
        started_at: queued_at
      )

      running = JobProgressRecord.track!(
        account_id: 1,
        job_class_name: "DownloadTranscriptsJob",
        run_id: "run-1",
        status: "running",
        started_at: running_at
      )

      expect(running.metadata["queued_at"]).to eq(queued.metadata["queued_at"])
      expect(running.started_at.to_i).to eq(running_at.to_i)
    end

    it "marks final zero-work records complete" do
      record = JobProgressRecord.track!(
        account_id: 1,
        job_class_name: "DashboardInsightJob",
        run_id: "done",
        status: "finished"
      )

      expect(record.percent).to eq(100)
      expect(record).not_to be_active
    end

    it "runs the configured after-commit hook" do
      calls = []
      JobProgressRecord.job_activity_after_commit = ->(record) { calls << record.run_id }

      JobProgressRecord.track!(
        account_id: 1,
        job_class_name: "IngestTranscriptsJob",
        run_id: "hooked",
        status: "running"
      )

      expect(calls).to eq([ "hooked" ])
    end

    it "supports a configured owner key while keeping account_id compatible" do
      record = TenantJobProgress.track!(
        tenant_id: 7,
        job_class_name: "TenantScopedJob",
        run_id: "tenant-run",
        status: "running"
      )

      expect(record.tenant_id).to eq(7)
      expect(TenantJobProgress.for_run(account_id: 7, job_class_name: "TenantScopedJob", run_id: "tenant-run")).to contain_exactly(record)
      expect(TenantJobProgress.for_run(tenant_id: 7, job_class_name: "TenantScopedJob", run_id: "tenant-run")).to contain_exactly(record)
    end

    it "rejects conflicting compatibility and configured owner keys" do
      expect {
        TenantJobProgress.track!(
          account_id: 7,
          tenant_id: 8,
          job_class_name: "TenantScopedJob",
          run_id: "tenant-run",
          status: "running"
        )
      }.to raise_error(ArgumentError, /conflicting owner values/)
    end
  end

  describe "validations and scopes" do
    it "rejects unknown statuses and out-of-range counts" do
      record = JobProgressRecord.new(
        account_id: 1,
        job_class_name: "Job",
        run_id: "run",
        status: "unknown",
        percent: 101,
        total: -1,
        completed: 0,
        skipped: 0,
        failed: 0,
        metadata: {},
        started_at: Time.current
      )

      expect(record).not_to be_valid
      expect(record.errors[:status]).to be_present
      expect(record.errors[:percent]).to be_present
      expect(record.errors[:total]).to be_present
    end

    it "finds active records and orders newest records first" do
      older = JobProgressRecord.track!(
        account_id: 1,
        job_class_name: "Job",
        run_id: "older",
        status: "running",
        started_at: 2.hours.ago
      )
      newer = JobProgressRecord.track!(
        account_id: 1,
        job_class_name: "Job",
        run_id: "newer",
        status: "scheduled",
        started_at: 1.hour.ago
      )
      JobProgressRecord.track!(
        account_id: 1,
        job_class_name: "Job",
        run_id: "done",
        status: "finished",
        started_at: 3.hours.ago
      )

      expect(JobProgressRecord.active).to contain_exactly(older, newer)
      expect(JobProgressRecord.recent_first.first).to eq(newer)
    end
  end
end
