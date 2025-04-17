# PostHog Elixir Client

[![Hex.pm](https://img.shields.io/hexpm/v/posthog.svg)](https://hex.pm/packages/posthog)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/posthog)

A powerful Elixir client for [PostHog](https://posthog.com), providing seamless integration with PostHog's analytics and feature flag APIs.

## Features

- Event Capture: Track user actions and custom events
- Feature Flags: Manage feature flags and multivariate tests
- Batch Processing: Send multiple events efficiently
- Custom Properties: Support for user, group, and person properties
- Flexible Configuration: Customizable JSON library and API version

## Installation

Add `posthog` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:posthog, "~> 1.0"}
  ]
end
```

You'll also need to include this library under your application tree. You can do so by including `:posthog` under your `:extra_applications` key inside `mix.exs`

```elixir
# mix.exs
def application do
  [
    extra_applications: [
      # ... your existing applications
      :posthog
    ]
  ]
```

### Application Customization

This library includes `Posthog.Application` because we bundle `Cachex` to avoid you from being charged too often for feature-flag checks against the same `{flag, distinct_id}` tuple.

This cache is located under `:posthog_feature_flag_cache`. If you want more control over the application, you can init it yourself in your own `application.ex`

```elixir
# lib/my_app/application.ex

defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      # Your other application children...
      {Posthog.Application, []}
    ]

    opts = [strategy: :one_for_one, name: MyApp.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

## Configuration

Add your PostHog configuration to your application's config:

```elixir
# config/config.exs
config :posthog,
  api_url: "https://app.posthog.com",  # Or your self-hosted PostHog instance URL
  api_key: "phc_your_project_api_key"

# Optional configurations
config :posthog,
  json_library: Jason  # Default JSON parser (optional)
```

## Usage

### Capturing Events

Simple event capture:

```elixir
# Basic event
Posthog.capture("page_view", distinct_id: "user_123")

# Event with properties
Posthog.capture("purchase", [
  distinct_id: "user_123",
  properties: %{
    product_id: "prod_123",
    price: 99.99,
    currency: "USD"
  }
])

# Event with custom timestamp
Posthog.capture("signup_completed",
  [distinct_id: "user_123"],
  DateTime.utc_now()
)

# Event with custom headers
Posthog.capture("login",
  [distinct_id: "user_123"],
  [headers: [{"x-forwarded-for", "127.0.0.1"}]]
)
```

### Batch Processing

Send multiple events in a single request:

```elixir
events = [
  {"page_view", [distinct_id: "user_123"], nil},
  {"button_click", [distinct_id: "user_123", properties: %{button_id: "signup"}], nil}
]

Posthog.batch(events)
```

### Feature Flags

Get all feature flags for a user:

```elixir
{:ok, flags} = Posthog.feature_flags("user_123")

# Response format:
# %{
#   "featureFlags" => %{"flag-1" => true, "flag-2" => "variant-b"},
#   "featureFlagPayloads" => %{
#     "flag-1" => true,
#     "flag-2" => %{"color" => "blue", "size" => "large"}
#   }
# }
```

Check specific feature flag:

```elixir
# Boolean feature flag
{:ok, flag} = Posthog.feature_flag("new-dashboard", "user_123")
# Returns: %Posthog.FeatureFlag{name: "new-dashboard", payload: true, enabled: true}

# Multivariate feature flag
{:ok, flag} = Posthog.feature_flag("pricing-test", "user_123")
# Returns: %Posthog.FeatureFlag{
#   name: "pricing-test",
#   payload: %{"price" => 99, "period" => "monthly"},
#   enabled: "variant-a"
# }

# Quick boolean check
if Posthog.feature_flag_enabled?("new-dashboard", "user_123") do
  # Show new dashboard
end
```

Feature flags with group properties:

```elixir
Posthog.feature_flags("user_123",
  groups: %{company: "company_123"},
  group_properties: %{company: %{industry: "tech"}},
  person_properties: %{email: "user@example.com"}
)
```

## Local Development

Run `bin/setup` to install development dependencies or run the following commands manually:

We recommend using `asdf` to manage Elixir and Erlang versions:

```sh
# Install required versions
asdf install

# Install dependencies
mix deps.get
mix compile
```

Run tests:

```sh
bin/test
```

(This runs `mix test`).

Format code:

```sh
bin/fmt
```

### Troubleshooting

If you encounter WX library issues during Erlang installation:

```sh
# Disable WX during installation
export KERL_CONFIGURE_OPTIONS="--without-wx"
asdf install
```

To persist this setting, add it to your shell configuration file (`~/.bashrc`, `~/.zshrc`, or `~/.profile`).

## Examples

There's an example console project in `examples/feature_flag_demo` that shows how to use the client. Follow the instructions in [the README](examples/feature_flag_demo/README.md) to run it.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
