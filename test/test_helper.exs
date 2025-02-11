# Start the Logger application
Application.ensure_all_started(:logger)

ExUnit.start()

# Set up minimal config required for tests
Application.put_env(:posthog, :api_key, "test_key")
Application.put_env(:posthog, :api_url, "https://app.posthog.com")
