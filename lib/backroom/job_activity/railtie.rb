# frozen_string_literal: true

require "rails/railtie"

module Backroom
  module JobActivity
    class Railtie < Rails::Railtie
      generators do
        require "generators/backroom/job_activity/install_generator"
      end
    end
  end
end
