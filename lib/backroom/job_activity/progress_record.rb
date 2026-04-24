# frozen_string_literal: true

require "active_support/concern"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/time"
require "time"

module Backroom
  module JobActivity
    module ProgressRecord
      extend ActiveSupport::Concern

      ACTIVE_STATUSES = %w[queued running scheduled].freeze
      FINAL_STATUSES = %w[finished failed cancelled].freeze

      included do
        owner_key = Backroom::JobActivity.owner_key

        class_attribute :job_activity_after_commit, instance_accessor: false, default: nil
        class_attribute :job_activity_owner_key, instance_accessor: false, default: owner_key

        validates owner_key, :job_class_name, :run_id, :status, :started_at, presence: true
        validates :status, inclusion: { in: ACTIVE_STATUSES + FINAL_STATUSES }
        validates :percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
        validates :total, :completed, :skipped, :failed, numericality: { greater_than_or_equal_to: 0 }

        scope :recent_first, -> { order(started_at: :desc, created_at: :desc) }
        scope :active, -> { where(status: ACTIVE_STATUSES) }
        scope :for_run, ->(account_id: nil, job_class_name:, run_id:, **owner_attributes) {
          owner_value = Backroom::JobActivity.extract_owner_value!(
            owner_key: klass.job_activity_owner_key,
            account_id: account_id,
            owner_attributes: owner_attributes
          )

          where(
            klass.job_activity_owner_key => owner_value,
            job_class_name: job_class_name.to_s,
            run_id: run_id.to_s
          )
        }

        after_commit :run_job_activity_after_commit
      end

      class_methods do
        def track!(
          account_id: nil,
          job_class_name:,
          run_id:,
          status: nil,
          phase: nil,
          total: nil,
          completed: nil,
          skipped: nil,
          failed: nil,
          metadata: nil,
          started_at: nil,
          finished_at: nil,
          **owner_attributes
        )
          owner_value = Backroom::JobActivity.extract_owner_value!(
            owner_key: job_activity_owner_key,
            account_id: account_id,
            owner_attributes: owner_attributes
          )

          record = for_run(
            job_activity_owner_key => owner_value,
            job_class_name: job_class_name,
            run_id: run_id
          ).first_or_initialize
          incoming_status = status.to_s if status.present?
          previous_status = record.status.to_s

          metadata_hash = record.metadata.is_a?(Hash) ? record.metadata.stringify_keys : {}
          metadata_hash.merge!(metadata.to_h.stringify_keys) if metadata.present?

          if incoming_status.present?
            if %w[queued scheduled].include?(incoming_status)
              metadata_hash["queued_at"] ||= (started_at || Time.current).iso8601
            elsif %w[queued scheduled].include?(previous_status) && incoming_status == "running"
              metadata_hash["queued_at"] ||= record.started_at&.iso8601 || Time.current.iso8601
              record.started_at = started_at || Time.current
            end

            record.status = incoming_status
          end

          record.phase = phase if phase.present?
          record.public_send("#{job_activity_owner_key}=", owner_value)
          record.total = normalize_count(total) unless total.nil?
          record.completed = normalize_count(completed) unless completed.nil?
          record.skipped = normalize_count(skipped) unless skipped.nil?
          record.failed = normalize_count(failed) unless failed.nil?
          record.metadata = metadata_hash
          record.started_at ||= started_at || Time.current
          record.finished_at = finished_at if finished_at.present?
          record.percent = calculate_percent(record.completed, record.total, status: record.status, fallback: record.percent)
          record.save!
          record
        end

        private

        def normalize_count(value)
          parsed = value.to_i
          parsed.negative? ? 0 : parsed
        end

        def calculate_percent(completed, total, status:, fallback:)
          if total.to_i <= 0 && completed.to_i <= 0
            return FINAL_STATUSES.include?(status.to_s) ? 100 : 0
          end
          return 100 if total.to_i <= 0 && completed.to_i.positive?
          return fallback.to_i.clamp(0, 100) if total.to_i <= 0

          ((completed.to_f / total.to_f) * 100).round.clamp(0, 100)
        end
      end

      def active?
        ACTIVE_STATUSES.include?(status.to_s)
      end

      private

      def run_job_activity_after_commit
        self.class.job_activity_after_commit&.call(self)
      end
    end
  end
end
