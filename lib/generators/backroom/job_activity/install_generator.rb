# frozen_string_literal: true

require "digest"
require "rails/generators"
require "rails/generators/active_record"
require "rails/generators/migration"

module Backroom
  module JobActivity
    module Generators
      class InstallGenerator < Rails::Generators::Base
        include ActiveRecord::Generators::Migration

        MAX_INDEX_NAME_LENGTH = 63
        INDEX_NAME_DIGEST_LENGTH = 8

        source_root File.expand_path("templates", __dir__)
        namespace "backroom:job_activity:install"

        argument :model_name, type: :string, required: false, desc: "Progress record model name"

        class_option :table_name, type: :string, desc: "Progress record table name"
        class_option :owner_key, type: :string, desc: "Owner foreign key column name"

        def create_model_file
          template "progress_record_model.rb.tt", File.join("app/models", "#{model_file_name}.rb")
        end

        def create_migration_file
          migration_template "create_progress_records.rb.tt", File.join("db/migrate", "create_#{table_name}.rb")
        end

        private

        def model_class_name
          model_name.presence || Backroom::JobActivity.default_model_name
        end

        def model_file_name
          model_class_name.underscore
        end

        def table_name
          options["table_name"].presence || model_class_name.tableize
        end

        def owner_key
          options["owner_key"].presence || Backroom::JobActivity.owner_key.to_s
        end

        def migration_class_name
          "Create#{table_name.camelize}"
        end

        def table_name_override?
          table_name != model_class_name.tableize
        end

        def run_index_name
          shortened_index_name("run")
        end

        def started_index_name
          shortened_index_name("started")
        end

        def shortened_index_name(suffix)
          base = "index_#{table_name}_on_#{owner_key}_job_#{suffix}"
          return base if base.length <= MAX_INDEX_NAME_LENGTH

          digest = Digest::SHA256.hexdigest(base).first(INDEX_NAME_DIGEST_LENGTH)
          truncated_base_length = MAX_INDEX_NAME_LENGTH - INDEX_NAME_DIGEST_LENGTH - 1
          "#{base.first(truncated_base_length)}_#{digest}"
        end
      end
    end
  end
end
