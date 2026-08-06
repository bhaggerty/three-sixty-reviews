# Union Station injects REDIS_URL as an env var at runtime (see memory:
# reference_union_station's pattern for other injected env vars); falls
# back to a local Redis for development.
redis_url = ENV.fetch("REDIS_URL", "redis://localhost:6379/1")

Sidekiq.configure_server { |config| config.redis = { url: redis_url } }
Sidekiq.configure_client { |config| config.redis = { url: redis_url } }
