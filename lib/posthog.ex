require Logger

defmodule Posthog do
  @moduledoc """
  A comprehensive Elixir client for PostHog's analytics and feature flag APIs.

  This module provides a high-level interface to PostHog's APIs, allowing you to:
  - Track user events and actions
  - Manage and evaluate feature flags
  - Handle multivariate testing
  - Process events in batch
  - Work with user, group, and person properties

  ## Configuration

  Add your PostHog configuration to your application config:

      config :posthog,
        api_url: "https://app.posthog.com",  # Or your self-hosted instance
        api_key: "phc_your_project_api_key"

  Optional configuration:

      config :posthog,
        json_library: Jason,   # Default JSON parser (optional)
        enabled_capture: true  # Whether to enable PostHog tracking (optional, defaults to true)
                               # Set to false in development/test environments to disable tracking

  ### Disabling PostHog

  You can disable PostHog tracking by setting `enabled: false` in your configuration.
  This is particularly useful in development or test environments where you don't want
  to send actual events to PostHog.

  When `enabled_capture` is set to `false`:
  - All `Posthog.capture/3` and `Posthog.batch/3` calls will succeed silently
  - PostHog will still communicate with the server for Feature Flags

  This is useful for:
  - Development and test environments where you don't want to pollute your PostHog instance
  - Situations where you need to temporarily disable tracking

  Example configuration for development:

      # config/dev.exs
      config :posthog,
        enabled_capture: false  # Disable tracking in development

  Example configuration for test:

      # config/test.exs
      config :posthog,
        enabled_capture: false  # Disable tracking in test environment

  ## Event Tracking

  Events can be tracked with various levels of detail:

      # Basic event
      Posthog.capture("page_view", distinct_id: "user_123")

      # Event with properties
      Posthog.capture("purchase", %{
        distinct_id: "user_123",
        product_id: "prod_123",
        price: 99.99
      })

      # Event with custom timestamp
      Posthog.capture("signup", "user_123", %{}, timestamp: DateTime.utc_now())

      # Event with custom headers (e.g., for IP forwarding)
      Posthog.capture("login", "user_123", %{}, headers: [{"x-forwarded-for", "127.0.0.1"}])

  ## Feature Flags

  PostHog feature flags can be used for feature management and A/B testing:

      # Get all feature flags for a user
      {:ok, flags} = Posthog.feature_flags("user_123")

      # Check specific feature flag
      {:ok, flag} = Posthog.feature_flag("new-dashboard", "user_123")

      # Quick boolean check
      if Posthog.feature_flag_enabled?("new-feature", "user_123") do
        # Show new feature
      end

      # Feature flags with group/person properties
      Posthog.feature_flags("user_123",
        groups: %{company: "company_123"},
        group_properties: %{company: %{industry: "tech"}},
        person_properties: %{email: "user@example.com"}
      )

  ## Batch Processing

  Multiple events can be sent in a single request for better performance:

      events = [
        {"page_view", [distinct_id: "user_123"], nil},
        {"button_click", [distinct_id: "user_123", button: "signup"], nil}
      ]

      Posthog.batch(events)

  Each event in the batch is a tuple of `{event_name, properties, timestamp}`.
  """

  @doc """
  Captures an event in PostHog.

  ## Parameters

    * `event` - The name of the event (string or atom)
    * `params` - Required parameters including `:distinct_id` and optional properties
    * `opts` - Optional parameters that can be either a timestamp or a keyword list of options

  ## Options

    * `:headers` - Additional HTTP headers for the request
    * `:groups` - Group properties for the event
    * `:group_properties` - Additional properties for groups
    * `:person_properties` - Properties for the person
    * `:timestamp` - Custom timestamp for the event

  ## Examples

      # Basic event
      Posthog.capture("page_view", "user_123")

      # Event with properties
      Posthog.capture("purchase", "user_123", %{
        product_id: "prod_123",
        price: 99.99
      })

      # Event with timestamp
      Posthog.capture("signup", "user_123", %{}, timestamp: DateTime.utc_now())

      # Event with custom headers
      Posthog.capture("login", "user_123", %{}, headers: [{"x-forwarded-for", "127.0.0.1"}])
  """
  @typep result() :: {:ok, term()} | {:error, term()}
  @typep cache_key() :: {:feature_flag_called, binary(), binary()}
  @typep feature_flag_called_event_properties_key() ::
           :"$feature_flag"
           | :"$feature_flag_response"
           | :"$feature_flag_id"
           | :"$feature_flag_version"
           | :"$feature_flag_reason"
           | :"$feature_flag_request_id"
           | :distinct_id
  @typep feature_flag_called_event_properties() :: %{
           feature_flag_called_event_properties_key() => any() | nil
         }

  alias Posthog.{Client, FeatureFlag}

  @spec capture(Client.event(), Client.distinct_id(), Client.properties(), Client.opts()) ::
          result()
  defdelegate capture(event, distinct_id, properties, opts \\ []), to: Client

  @doc """
  Sends multiple events to PostHog in a single request.

  ## Parameters

    * `events` - List of event tuples in the format `{event_name, distinct_id, properties}`
    * `opts` - Optional parameters for the batch request

  ## Examples

      events = [
        {"page_view", "user_123", %{}},
        {"button_click", "user_123", %{button: "signup"}}
      ]

      Posthog.batch(events)
  """
  @spec batch(list(tuple()), keyword()) :: result()
  defdelegate batch(events, opts \\ []), to: Client

  @doc """
  Retrieves all feature flags for a given distinct ID.

  ## Parameters

    * `distinct_id` - The unique identifier for the user
    * `opts` - Optional parameters for the feature flag request

  ## Options

    * `:groups` - Group properties for feature flag evaluation
    * `:group_properties` - Additional properties for groups
    * `:person_properties` - Properties for the person

  ## Examples

      # Basic feature flags request
      {:ok, flags} = Posthog.feature_flags("user_123")

      # With group properties
      {:ok, flags} = Posthog.feature_flags("user_123",
        groups: %{company: "company_123"},
        group_properties: %{company: %{industry: "tech"}}
      )
  """
  @spec feature_flags(binary(), keyword()) :: result()
  defdelegate feature_flags(distinct_id, opts \\ []), to: Client

  @doc """
  Retrieves information about a specific feature flag for a given distinct ID.

  ## Parameters

    * `flag` - The name of the feature flag
    * `distinct_id` - The unique identifier for the user
    * `opts` - Optional parameters for the feature flag request

  ## Examples

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
  """
  @spec feature_flag(binary(), binary(), Client.feature_flag_opts()) :: result()
  def feature_flag(flag, distinct_id, opts \\ []) do
    with {:ok, response} <- Client._decide_request(distinct_id, opts),
         enabled when not is_nil(enabled) <- response.feature_flags[flag] do
      # Only capture if send_feature_flag_event is true (default)
      if Keyword.get(opts, :send_feature_flag_event, true),
        do:
          capture_feature_flag_called_event(
            distinct_id,
            %{
              "$feature_flag" => flag,
              "$feature_flag_response" => enabled
            },
            response
          )

      {:ok, FeatureFlag.new(flag, enabled, Map.get(response.feature_flag_payloads, flag))}
    else
      {:error, _} = err -> err
      nil -> {:error, :not_found}
    end
  end

  @spec capture_feature_flag_called_event(
          Client.distinct_id(),
          feature_flag_called_event_properties(),
          map()
        ) ::
          :ok
  defp capture_feature_flag_called_event(distinct_id, properties, response) do
    # Create a unique key for this distinct_id and flag combination
    cache_key = {:feature_flag_called, distinct_id, properties["$feature_flag"]}

    # Check if we've seen this combination before using Cachex
    case Cachex.exists?(Posthog.Application.cache_name(), cache_key) do
      {:ok, false} ->
        do_capture_feature_flag_called_event(cache_key, distinct_id, properties, response)

      # Should be `{:error, :no_cache}` but Dyalixir is wrongly assuming that doesn't exist
      {:error, _} ->
        # Cache doesn't exist, let's capture the event PLUS notify user they should be initing it
        do_capture_feature_flag_called_event(cache_key, distinct_id, properties, response)

        Logger.error("""
        [posthog] Cachex process `#{inspect(Posthog.Application.cache_name())}` is not running.

        ➤ This likely means you forgot to include `posthog` as an application dependency (mix.exs):

            Example:

            extra_applications: [..., :posthog]


        ➤ Or, add `Posthog.Application` to your supervision tree (lib/my_lib/application.ex).

            Example:
                {Posthog.Application, []}
        """)

      {:ok, true} ->
        # Entry already exists, no need to do anything
        :ok
    end
  end

  @spec do_capture_feature_flag_called_event(
          cache_key(),
          Client.distinct_id(),
          feature_flag_called_event_properties(),
          map()
        ) :: :ok
  defp do_capture_feature_flag_called_event(cache_key, distinct_id, properties, response) do
    flag = properties["$feature_flag"]

    properties =
      if Map.has_key?(response, :flags) do
        Map.merge(properties, %{
          "$feature_flag_id" => response.flags[flag]["metadata"]["id"],
          "$feature_flag_version" => response.flags[flag]["metadata"]["version"],
          "$feature_flag_reason" => response.flags[flag]["reason"]["description"]
        })
      else
        properties
      end

    properties =
      if Map.get(response, :request_id) do
        Map.put(properties, "$feature_flag_request_id", response.request_id)
      else
        properties
      end

    # Send the event to our server
    Client.capture("$feature_flag_called", distinct_id, properties, [])

    # Add new entry to cache using Cachex
    Cachex.put(Posthog.Application.cache_name(), cache_key, true)

    :ok
  end

  @doc """
  Checks if a feature flag is enabled for a given distinct ID.

  This is a convenience function that returns a boolean instead of a result tuple.
  For multivariate flags, returns true if the flag has any value set.

  ## Parameters

    * `flag` - The name of the feature flag
    * `distinct_id` - The unique identifier for the user
    * `opts` - Optional parameters for the feature flag request

  ## Examples

      if Posthog.feature_flag_enabled?("new-dashboard", "user_123") do
        # Show new dashboard
      end
  """
  @spec feature_flag_enabled?(binary(), binary(), keyword()) :: boolean()
  def feature_flag_enabled?(flag, distinct_id, opts \\ []) do
    flag
    |> feature_flag(distinct_id, opts)
    |> case do
      {:ok, %FeatureFlag{enabled: false}} -> false
      {:ok, %FeatureFlag{}} -> true
      _ -> false
    end
  end
end
