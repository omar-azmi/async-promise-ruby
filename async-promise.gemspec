# frozen_string_literal: true

require_relative "lib/async/promise"

Gem::Specification.new do |spec|
	spec.name = "async-promise"
	spec.version = Async::Promise::VERSION
	spec.authors = ["Omar Azmi"]
	spec.email = ["64020006+omar-azmi@users.noreply.github.com"]
	spec.license = "CC-BY-NC-SA-4.0"

	spec.summary = "Asynchronous Javascript style Promises for Ruby."
	spec.description = \
		"An Asynchronous Promise library for Ruby, built over the \"async\" gem, providing Javascript ES6 style Promises. " \
		"It also includes utilities like ES6-style \"fetch\" that returns a Promise."
	spec.homepage = "https://github.com/omar-azmi/async-promise-ruby"
	spec.required_ruby_version = ">= 3.1.1"

	spec.metadata["allowed_push_host"] = "https://rubygems.org"

	spec.metadata["homepage_uri"] = spec.homepage
	spec.metadata["source_code_uri"] = "#{spec.homepage}.git"
	spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/changelog.md"

	# Specify which files should be added to the gem when it is released.
	# We include all ".rb" and ".md" files inside of the "./lib/" directory, and also include the ".md" files in the root directory.
	repo_root_dir = __dir__
	spec.files = Dir.glob(["lib/**/*.{rb,md}", "sig/**/*.rbs", "*.md",], File::FNM_DOTMATCH, base: repo_root_dir)

	# Dependencies

	# Runtime dependencies
	spec.add_dependency("async", "~> 2.17")

	# Development dependencies
	spec.add_development_dependency("rubocop", "~> 1.65")
	spec.add_development_dependency("solargraph", "~> 0.50.0")

	# Test dependencies
	spec.add_development_dependency("sus", "~> 0.31.0")
end
