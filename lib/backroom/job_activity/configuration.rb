# frozen_string_literal: true

module Backroom
  module JobActivity
    class Configuration
      attr_accessor :owner_key, :default_table_name

      def initialize
        @owner_key = :account_id
        @default_table_name = :job_progress_records
      end
    end
  end
end
