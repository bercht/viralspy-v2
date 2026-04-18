require "spec_helper"
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "shoulda/matchers"

require "webmock/rspec"
WebMock.disable_net_connect!(allow_localhost: true)

require "vcr"
VCR.configure do |config|
  config.cassette_library_dir = "spec/fixtures/vcr_cassettes"
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.filter_sensitive_data("<APIFY_TOKEN>") { ENV["APIFY_API_TOKEN"] }
  config.filter_sensitive_data("<OPENAI_KEY>") { ENV["OPENAI_API_KEY"] }
  config.filter_sensitive_data("<ANTHROPIC_KEY>") { ENV["ANTHROPIC_API_KEY"] }
end

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods

  config.before(:each, type: :request) do
    host! "localhost"
  end

  config.around(:each) do |example|
    if example.metadata[:skip_tenant]
      example.run
    else
      ActsAsTenant.without_tenant do
        example.run
      end
    end
  end
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
