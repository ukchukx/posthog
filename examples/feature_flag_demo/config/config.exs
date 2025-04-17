import Config

# Remove trailing slash from API URL if present
api_url = System.get_env("POSTHOG_API_URL", "https://us.posthog.com")
api_url = if String.ends_with?(api_url, "/"), do: String.slice(api_url, 0..-2//-1), else: api_url

config :posthog,
  api_url: api_url,
  api_key: System.get_env("POSTHOG_API_KEY")
