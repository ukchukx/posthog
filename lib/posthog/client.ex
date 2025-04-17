require Logger

defmodule Posthog.Client do
  @moduledoc """
  Low-level HTTP client for interacting with PostHog's API.

  This module handles the direct HTTP communication with PostHog's API endpoints.
  It provides functions for:
  - Sending event capture requests
  - Processing batch events
  - Retrieving feature flag information

  While this module can be used directly, it's recommended to use the higher-level
  functions in the `Posthog` module instead.

  ## Configuration

  The client uses the following configuration from your application:

      config :posthog,
        api_url: "https://app.posthog.com",  # Required
        api_key: "phc_your_project_api_key", # Required
        json_library: Jason,                 # Optional (default: Jason)
        enabled_capture: true,               # Optional (default: true)
        http_client: Posthog.HTTPClient.Hackney,  # Optional (default: Posthog.HTTPClient.Hackney)
        http_client_opts: [                  # Optional
          timeout: 5_000,    # 5 seconds
          retries: 3,        # Number of retries
          retry_delay: 1_000 # 1 second between retries
        ]

  ### Disabling capture

  When `enabled_capture` is set to `false`:
  - All `Posthog.capture/3` and `Posthog.batch/3` calls will succeed silently
  - PostHog will still communicate with the server for Feature Flags

  This is useful for:
  - Development and test environments where you don't want to pollute your PostHog instance
  - Situations where you need to temporarily disable tracking

  Example configuration for disabling the client:

      # config/dev.exs or config/test.exs
      config :posthog,
        enabled_capture: false

  ## API Endpoints

  The client interacts with the following PostHog API endpoints:
  - `/capture` - For sending individual and batch events
  - `/decide` - For retrieving feature flag information

  ## Error Handling

  All functions return a result tuple:
  - `{:ok, response}` for successful requests
  - `{:error, response}` for failed requests with a response
  - `{:error, term()}` for other errors (network issues, etc.)

  ## Examples

      # Capture an event
      Posthog.Client.capture("page_view", "user_123")

      # Send batch events
      events = [
        {"page_view", "user_123", %{}},
        {"click", "user_123", %{}}
      ]
      Posthog.Client.batch(events, timestamp: DateTime.utc_now())

      # Get feature flags
      Posthog.Client.feature_flags("user_123", groups: %{team: "engineering"})
  """

  alias Posthog.FeatureFlag

  @typedoc """
  Result of a PostHog operation.
  """
  @type result() :: {:ok, response()} | {:error, response() | term()}

  @typedoc """
  HTTP headers in the format expected by :hackney.
  """
  @type headers :: [{binary(), binary()}]

  @typedoc """
  Response from the PostHog API.
  Contains the status code, headers, and parsed JSON body (if any).
  """
  @type response :: %{status: pos_integer(), headers: headers(), body: map() | nil}

  @typedoc """
  Event name, can be either an atom or a binary string.
  """
  @type event :: atom() | binary()

  @typedoc """
  Distinct ID for the person or group.
  """
  @type distinct_id :: binary()

  @typedoc """
  Properties that can be attached to events or feature flag requests.
  """
  @type properties :: %{optional(atom() | String.t()) => term()}

  @typedoc """
  Timestamp for events. Can be a DateTime, NaiveDateTime, or ISO8601 string.
  """
  @type timestamp :: String.t()

  @typedoc """
  Options that can be passed to API requests.

  * `:headers` - Additional HTTP headers to include in the request
  * `:groups` - Group properties for feature flag evaluation
  * `:group_properties` - Additional properties for groups
  * `:person_properties` - Properties for the person
  * `:timestamp` - Custom timestamp for events
  * `:uuid` - Custom UUID for the event
  """
  @type opts :: [
          headers: headers(),
          groups: map(),
          group_properties: map(),
          person_properties: map(),
          timestamp: timestamp(),
          uuid: Uniq.UUID.t()
        ]

  @typedoc """
  Feature flag specific options that should not be passed to capture events.

  * `:send_feature_flag_event` - Whether to capture the `$feature_flag_called` event (default: true)
  """
  @type feature_flag_opts :: opts() | [send_feature_flag_event: boolean()]

  @typedoc """
  Cache key for the `$feature_flag_called` event.
  """
  @type cache_key() :: {:feature_flag_called, binary(), binary()}

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

  # Adds default headers to the request.
  #
  # ## Parameters
  #
  #   * `additional_headers` - List of additional headers to include
  #
  # ## Examples
  #
  #     headers([{"x-forwarded-for", "127.0.0.1"}])
  @spec headers(headers()) :: headers()
  defp headers(additional_headers) do
    Enum.concat(additional_headers || [], [{"content-type", "application/json"}])
  end

  @doc """
  Captures a single event in PostHog.

  ## Parameters

    * `event` - The name of the event (string or atom)
    * `params` - Event properties including `:distinct_id`
    * `opts` - Additional options (see `t:opts/0`)

  ## Examples

      # Basic event
      Posthog.Client.capture("page_view", "user_123")

      # Event with properties and timestamp
      Posthog.Client.capture("purchase", "user_123", %{
        product_id: "123",
        price: 99.99
      }, timestamp: DateTime.utc_now())

      # Event with custom headers
      Posthog.Client.capture("login", "user_123", %{}, headers: [{"x-forwarded-for", "127.0.0.1"}])
  """
  @spec capture(event(), distinct_id(), properties(), opts()) :: result()
  def capture(event, distinct_id, properties \\ %{}, opts \\ []) when is_list(opts) do
    if Posthog.Config.enabled_capture?() do
      posthog_event = Posthog.Event.new(event, distinct_id, properties, opts)
      post!("/capture", Posthog.Event.to_api_payload(posthog_event), headers(opts[:headers]))
    else
      disabled_capture_response()
    end
  end

  @doc """
  Sends multiple events to PostHog in a single request.

  ## Parameters

    * `events` - List of event tuples in the format `{event_name, distinct_id, properties}`
    * `opts` - Additional options (see `t:opts/0`)
    * `headers` - Additional HTTP headers

  ## Examples

      events = [
        {"page_view", "user_123", %{}},
        {"click", "user_123", %{button: "signup"}}
      ]

      Posthog.Client.batch(events, %{timestamp: DateTime.utc_now()})
  """
  @spec batch([{event(), distinct_id(), properties()}], opts(), headers()) :: result()
  def batch(events, opts) when is_list(opts) do
    batch(events, opts, headers(opts[:headers]))
  end

  def batch(events, opts, headers) do
    if Posthog.Config.enabled_capture?() do
      timestamp = Keyword.get_lazy(opts, :timestamp, fn -> DateTime.utc_now() end)

      posthog_events =
        for {event, distinct_id, properties} <- events do
          Posthog.Event.new(event, distinct_id, properties, timestamp: timestamp)
        end

      post!("/capture", Posthog.Event.batch_payload(posthog_events), headers)
    else
      disabled_capture_response()
    end
  end

  @doc """
  Retrieves feature flags for a given distinct ID.

  ## Parameters

    * `distinct_id` - The unique identifier for the user
    * `opts` - Additional options (see `t:opts/0`)

  ## Examples

      # Basic feature flags request
      Posthog.Client.feature_flags("user_123")

      # With group properties
      Posthog.Client.feature_flags("user_123",
        groups: %{company: "company_123"},
        group_properties: %{company: %{industry: "tech"}}
      )
  """
  @spec feature_flags(binary(), opts()) :: result()
  def feature_flags(distinct_id, opts) do
    case _decide_request(distinct_id, opts) do
      {:ok, response} ->
        {:ok,
         %{
           feature_flags: response.feature_flags,
           feature_flag_payloads: response.feature_flag_payloads
         }}

      err ->
        err
    end
  end

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
  @spec feature_flag(binary(), binary(), feature_flag_opts()) :: result()
  def feature_flag(flag, distinct_id, opts \\ []) do
    with {:ok, response} <- _decide_request(distinct_id, opts),
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
          distinct_id(),
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
          distinct_id(),
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
    # NOTE: Calling this with `Posthog.Client.capture/4` rather than `capture/4`
    #       because mocks won't work properly unless we use the fully defined function
    Posthog.Client.capture("$feature_flag_called", distinct_id, properties, [])

    # Add new entry to cache using Cachex
    Cachex.put(Posthog.Application.cache_name(), cache_key, true)

    :ok
  end

  @doc false
  def _decide_request(distinct_id, opts) do
    body =
      opts
      |> Keyword.take(~w[groups group_properties person_properties]a)
      |> Enum.reduce(%{distinct_id: distinct_id}, fn {k, v}, acc -> Map.put(acc, k, v) end)

    case post!("/decide?v=4", body, headers(opts[:headers])) do
      {:ok, %{body: body}} -> {:ok, Posthog.FeatureFlag.process_response(body)}
      err -> err
    end
  end

  @doc false
  @spec post!(binary(), map(), headers()) :: {:ok, response()} | {:error, response() | term()}
  defp post!(path, %{} = body, headers) do
    body =
      body
      |> Map.put(:api_key, Posthog.Config.api_key())
      |> encode(Posthog.Config.json_library())

    url = Posthog.Config.api_url() <> path

    Posthog.Config.http_client().post(
      url,
      body,
      headers,
      Posthog.Config.http_client_opts()
    )
  end

  @doc false
  defp disabled_capture_response do
    {:ok, %{status: 200, headers: [], body: nil}}
  end

  @doc false
  @spec encode(term(), module()) :: iodata()
  defp encode(data, Jason), do: Jason.encode_to_iodata!(data)
  defp encode(data, library), do: library.encode!(data)
end
