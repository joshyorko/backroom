# frozen_string_literal: true

require "active_support/core_ext/string/inflections"
require "backroom/job_activity/version"
require "backroom/job_activity/configuration"
require "backroom/job_activity/progress_record"
require "backroom/job_activity/railtie" if defined?(Rails::Railtie)

module Backroom
  module JobActivity
    class << self
      def config
        @config ||= Configuration.new
      end

      def configure
        yield(config)
      end

      def owner_key
        config.owner_key.to_sym
      end

      def default_table_name
        config.default_table_name.to_s
      end

      def default_model_name
        default_table_name.classify
      end

      def extract_owner_value!(owner_key:, account_id:, owner_attributes:)
        attributes = owner_attributes.transform_keys(&:to_sym)
        owner_value = attributes.delete(owner_key)

        if !owner_value.nil? && !account_id.nil? && owner_value != account_id
          raise ArgumentError, "conflicting owner values for #{owner_key} and account_id"
        end

        owner_value = account_id if owner_value.nil?

        if attributes.any?
          raise ArgumentError, "unknown keywords: #{attributes.keys.map(&:inspect).join(', ')}"
        end

        owner_value
      end
    end
  end
end
