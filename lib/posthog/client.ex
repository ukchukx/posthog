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

  @lib_version Mix.Project.config()[:version]
  @lib_name "posthog-elixir"

  import Posthog.Guard, only: [is_keyword_list: 1]

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
  @spec capture(event(), distinct_id(), properties(), opts()) ::
          {:ok, response()} | {:error, response() | term()}
  def capture(event, distinct_id, properties \\ %{}, opts \\ []) when is_list(opts) do
    if Posthog.Config.enabled_capture?() do
      timestamp =
        Keyword.get_lazy(opts, :timestamp, fn ->
          DateTime.utc_now() |> DateTime.to_iso8601()
        end)

      uuid = Keyword.get(opts, :uuid)

      post!(
        "/capture",
        build_event(event, distinct_id, properties, timestamp, uuid),
        headers(opts[:headers])
      )
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
  @spec batch([{event(), distinct_id(), properties()}], opts(), headers()) ::
          {:ok, response()} | {:error, response() | term()}
  def batch(events, opts) when is_list(opts) do
    batch(events, opts, headers(opts[:headers]))
  end

  def batch(events, opts, headers) do
    if Posthog.Config.enabled_capture?() do
      timestamp = Keyword.get_lazy(opts, :timestamp, fn -> DateTime.utc_now() end)

      body =
        for {event, distinct_id, properties} <- events,
            do: build_event(event, distinct_id, properties, timestamp)

      post!("/capture", %{batch: body}, headers)
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
  @spec feature_flags(binary(), opts()) ::
          {:ok, Posthog.FeatureFlag.flag_response()} | {:error, response() | term()}
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

  @doc false
  def _decide_request(distinct_id, opts) do
    body =
      opts
      |> Keyword.take(~w[groups group_properties person_properties]a)
      |> Enum.reduce(%{distinct_id: distinct_id}, fn {k, v}, acc -> Map.put(acc, k, v) end)

    case post!("/decide?v=4", body, headers(opts[:headers])) do
      {:ok, %{body: body}} ->
        if Map.has_key?(body, "flags") do
          flags = body["flags"]

          feature_flags =
            Map.new(flags, fn {k, v} ->
              {k, if(v["variant"], do: v["variant"], else: v["enabled"])}
            end)

          feature_flag_payloads =
            Map.new(flags, fn {k, v} ->
              {k,
               if(v["metadata"]["payload"],
                 do: decode_feature_flag_payload(v["metadata"]["payload"]),
                 else: nil
               )}
            end)

          {:ok,
           %{
             flags: flags,
             feature_flags: feature_flags,
             feature_flag_payloads: feature_flag_payloads,
             request_id: body["requestId"]
           }}
        else
          {:ok,
           %{
             feature_flags: Map.get(body, "featureFlags", %{}),
             feature_flag_payloads: decode_feature_flag_payloads(body),
             request_id: body["requestId"]
           }}
        end

      err ->
        err
    end
  end

  @doc """
  Builds an event payload for the PostHog API.

  ## Parameters

    * `event` - The name of the event
    * `distinct_id` - The distinct ID for the person or group
    * `properties` - Event properties
    * `timestamp` - Optional timestamp for the event
    * `uuid` - Optional UUID for the event

  ## Examples

      build_event("page_view", "user_123", nil)
      build_event("purchase", "user_123", %{price: 99.99}, DateTime.utc_now())
      build_event("purchase", "user_123", %{price: 99.99}, DateTime.utc_now(), Uniq.UUID.uuid7())
  """
  @spec build_event(event(), distinct_id(), properties(), timestamp(), Uniq.UUID.t() | nil) ::
          map()
  def build_event(event, distinct_id, properties, timestamp, uuid \\ nil) do
    properties = Map.merge(lib_properties(), deep_stringify_keys(Map.new(properties)))
    uuid = uuid || Uniq.UUID.uuid7()

    %{
      event: to_string(event),
      distinct_id: distinct_id,
      properties: properties,
      uuid: uuid,
      timestamp: timestamp
    }
  end

  @doc false
  defp deep_stringify_keys(term) when is_map(term) do
    term
    |> Enum.map(fn {k, v} -> {to_string(k), deep_stringify_keys(v)} end)
    |> Enum.into(%{})
  end

  defp deep_stringify_keys(term) when is_keyword_list(term) do
    term
    |> Enum.map(fn {k, v} -> {to_string(k), deep_stringify_keys(v)} end)
    |> Enum.into(%{})
  end

  defp deep_stringify_keys(term) when is_list(term), do: Enum.map(term, &deep_stringify_keys/1)
  defp deep_stringify_keys(term), do: term

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

  @doc false
  @spec lib_properties() :: map()
  defp lib_properties do
    %{
      "$lib" => @lib_name,
      "$lib_version" => @lib_version
    }
  end

  defp decode_feature_flag_payloads(data) do
    data
    |> Map.get("featureFlagPayloads", %{})
    |> Enum.reduce(%{}, fn {k, v}, map ->
      Map.put(map, k, decode_feature_flag_payload(v))
    end)
  end

  defp decode_feature_flag_payload(payload) do
    case Jason.decode(payload) do
      {:ok, decoded} -> decoded
      {:error, _} -> payload
    end
  end
end
