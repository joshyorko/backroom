# frozen_string_literal: true

require_relative "lib/backroom/job_activity/version"

Gem::Specification.new do |spec|
  spec.name = "backroom"
  spec.version = Backroom::JobActivity::VERSION
  spec.authors = [ "Backroom" ]
  spec.email = [ "maintainers@example.com" ]

  spec.summary = "Reusable ActiveRecord job progress tracking for Backroom-style Rails apps."
  spec.description = "Extracted Backroom job activity progress-record concern with host-owned persistence and UI integration."
  spec.homepage = "https://example.com/backroom"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server if this gem is published."
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "CHANGELOG.md",
      "LICENSE.txt",
      "README.md",
      "COPILOT_BOOTSTRAP_PROMPT.md",
      "lib/**/*.rb",
      "lib/generators/**/*"
    ]
  end

  spec.bindir = "exe"
  spec.require_paths = [ "lib" ]

  spec.add_dependency "activerecord", ">= 7.1", "< 9.0"
  spec.add_dependency "activesupport", ">= 7.1", "< 9.0"
  spec.add_dependency "railties", ">= 7.1", "< 9.0"

  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "rspec", ">= 3.13"
  spec.add_development_dependency "sqlite3", ">= 2.0"
end
