# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"
require "rails/generators/migration"

module Backroom
  module JobActivity
    module Generators
      class InstallGenerator < Rails::Generators::Base
        include ActiveRecord::Generators::Migration

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
      end
    end
  end
end
