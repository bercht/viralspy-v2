Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch("SIDEKIQ_REDIS_URL", "redis://redis:6379/1") }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch("SIDEKIQ_REDIS_URL", "redis://redis:6379/1") }
end
