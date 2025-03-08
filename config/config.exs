import Config

if config_env() == :test do
  config :posthog, api_key: "phc_randomrandomrandom", api_url: "https://us.posthog.com"
end
