defmodule Posthog.Event do
  @moduledoc """
  Represents a PostHog event with all its properties and metadata.

  This struct encapsulates all the information needed to send an event to PostHog,
  including the event name, distinct ID, properties, timestamp, and UUID.

  ## Examples

      # Create a basic event
      iex> event = Posthog.Event.new("page_view", "user_123")
      iex> event.event
      "page_view"
      iex> event.distinct_id
      "user_123"
      iex> event.properties
      %{}
      iex> is_binary(event.uuid)
      true
      iex> is_binary(event.timestamp)
      true

      # Create an event with properties
      iex> event = Posthog.Event.new("purchase", "user_123", %{price: 99.99})
      iex> event.properties
      %{price: 99.99}

      # Create an event with custom timestamp
      iex> timestamp = "2023-01-01T00:00:00Z"
      iex> event = Posthog.Event.new("login", "user_123", %{}, timestamp: timestamp)
      iex> event.timestamp
      "2023-01-01T00:00:00Z"

      # Create an event with custom UUID
      iex> uuid = "123e4567-e89b-12d3-a456-426614174000"
      iex> event = Posthog.Event.new("signup", "user_123", %{}, uuid: uuid)
      iex> event.uuid
      "123e4567-e89b-12d3-a456-426614174000"

      # Convert event to API payload
      iex> event = Posthog.Event.new("page_view", "user_123", %{page: "home"})
      iex> payload = Posthog.Event.to_api_payload(event)
      iex> payload.event
      "page_view"
      iex> payload.distinct_id
      "user_123"
      iex> payload.properties["page"]
      "home"
      iex> payload.properties["$lib"]
      "posthog-elixir"
      iex> is_binary(payload.uuid)
      true
      iex> is_binary(payload.timestamp)
      true

      # Create batch payload
      iex> events = [
      ...>   Posthog.Event.new("page_view", "user_123", %{page: "home"}),
      ...>   Posthog.Event.new("click", "user_123", %{button: "signup"})
      ...> ]
      iex> batch = Posthog.Event.batch_payload(events)
      iex> length(batch.batch)
      2
      iex> [first, second] = batch.batch
      iex> first.event
      "page_view"
      iex> second.event
      "click"
  """

  @type t :: %__MODULE__{
          event: String.t(),
          distinct_id: String.t(),
          properties: map(),
          uuid: String.t(),
          timestamp: String.t()
        }

  @type event_name :: atom() | String.t()
  @type distinct_id :: String.t()
  @type properties :: map()
  @type timestamp :: String.t() | DateTime.t() | NaiveDateTime.t()

  import Posthog.Guard, only: [is_keyword_list: 1]

  defstruct [:event, :distinct_id, :properties, :uuid, :timestamp]

  @lib_name "posthog-elixir"
  @lib_version Mix.Project.config()[:version]

  @doc """
  Creates a new PostHog event.

  ## Parameters

    * `event` - The name of the event (string or atom)
    * `distinct_id` - The distinct ID for the person or group
    * `properties` - Event properties (optional, defaults to empty map)
    * `timestamp` - Optional timestamp for the event (defaults to current UTC time)
    * `uuid` - Optional UUID for the event (defaults to a new UUID7)

  ## Examples

      # Basic event
      Posthog.Event.new("page_view", "user_123")

      # Event with properties
      Posthog.Event.new("purchase", "user_123", %{price: 99.99})

      # Event with custom timestamp
      Posthog.Event.new("login", "user_123", %{}, timestamp: DateTime.utc_now())
  """
  @spec new(event_name(), distinct_id(), properties(), keyword()) :: t()
  def new(event, distinct_id, properties \\ %{}, opts \\ []) do
    timestamp =
      Keyword.get_lazy(opts, :timestamp, fn ->
        DateTime.utc_now() |> DateTime.to_iso8601()
      end)

    uuid = Keyword.get(opts, :uuid) || Uniq.UUID.uuid7()

    %__MODULE__{
      event: to_string(event),
      distinct_id: distinct_id,
      properties: properties,
      uuid: uuid,
      timestamp: timestamp
    }
  end

  @doc """
  Converts the event struct to a map suitable for sending to the PostHog API.
  """
  @spec to_api_payload(t()) :: map()
  def to_api_payload(%__MODULE__{} = event) do
    %{
      event: event.event,
      distinct_id: event.distinct_id,
      properties: deep_stringify_keys(Map.merge(lib_properties(), Map.new(event.properties))),
      uuid: event.uuid,
      timestamp: event.timestamp
    }
  end

  @doc """
  Creates a batch payload from a list of events.
  """
  @spec batch_payload([t()]) :: map()
  def batch_payload(events) do
    %{batch: Enum.map(events, &to_api_payload/1)}
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
  defp lib_properties do
    %{
      "$lib" => @lib_name,
      "$lib_version" => @lib_version
    }
  end
end
