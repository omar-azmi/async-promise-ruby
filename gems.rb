# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in async-promise.gemspec
gemspec

gem "async", "~> 2.17", require: false

group :development do
	gem "rubocop", "~> 1.65", require: false
	gem "solargraph", "~> 0.50.0", require: false
end

group :test do
	gem "sus", "~> 0.31.0", require: false
end
