source "https://rubygems.org"

ruby "3.3.6"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.6"

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Autenticação & Autorização
gem "devise"
gem "pundit"

# Multi-tenancy
gem "acts_as_tenant"

# Background jobs
gem "sidekiq", "~> 7.0"
gem "redis", "~> 5.0"

# IA
gem "ruby-openai"
gem "anthropic"
gem "assemblyai", "~> 1.0"

# pgvector
gem "pgvector"
gem "neighbor"

# HTTP
gem "httparty"

# Components
gem "view_component"

# Env
gem "dotenv-rails", groups: %i[ development test ]

group :development do
  gem "web-console"
  gem "rubocop-rails-omakase", require: false
  gem "erb_lint", require: false
  gem "pry-rails"
end

group :development, :test do
  gem "debug", platforms: %i[ mri windows ]
  gem "rspec-rails", "~> 6.0"
  gem "factory_bot_rails"
  gem "faker"
end

group :test do
  gem "webmock"
  gem "vcr"
  gem "shoulda-matchers"
  gem "capybara"
end
