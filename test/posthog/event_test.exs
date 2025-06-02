defmodule Posthog.EventTest do
  use ExUnit.Case, async: true
  doctest Posthog.Event

  alias Posthog.Event

  defstruct [:name]

  describe "new/4" do
    test "creates an event with default values" do
      event = Event.new("test_event", "user_123")

      assert event.event == "test_event"
      assert event.distinct_id == "user_123"
      assert event.properties == %{}
      assert is_binary(event.timestamp)

      # Generated valid UUID
      assert event.uuid
      assert is_binary(event.uuid)
      assert String.length(event.uuid) == 36
    end

    test "creates an event with properties" do
      properties = %{price: 99.99, quantity: 2}
      event = Event.new("purchase", "user_123", properties)

      assert event.event == "purchase"
      assert event.distinct_id == "user_123"
      assert event.properties == properties
    end

    test "creates an event with custom timestamp" do
      timestamp = "2023-01-01T00:00:00Z"
      event = Event.new("login", "user_123", %{}, timestamp: timestamp)

      assert event.timestamp == timestamp
    end

    test "creates an event with custom UUID" do
      uuid = "123e4567-e89b-12d3-a456-426614174000"
      event = Event.new("signup", "user_123", %{}, uuid: uuid)

      assert event.uuid == uuid
    end

    test "converts atom event name to string" do
      event = Event.new(:page_view, "user_123")

      assert event.event == "page_view"
    end
  end

  describe "to_api_payload/1" do
    test "converts event to API payload" do
      event = Event.new("page_view", "user_123", %{page: "home"})
      payload = Event.to_api_payload(event)

      assert payload.event == "page_view"
      assert payload.distinct_id == "user_123"
      assert payload.properties["page"] == "home"
      assert payload.properties["$lib"] == "posthog-elixir"
      assert payload.properties["$lib_version"] == Mix.Project.config()[:version]
      assert is_binary(payload.uuid)
      assert is_binary(payload.timestamp)
    end

    test "overrides library properties with custom properties" do
      event =
        Event.new(
          "page_view",
          "user_123",
          %{"$lib" => "custom", "$lib_version" => "1.0.0"}
        )

      payload = Event.to_api_payload(event)

      assert payload.properties["$lib"] == "custom"
      assert payload.properties["$lib_version"] == "1.0.0"
    end

    test "deep stringifies property keys" do
      event = Event.new("test", "user_123", %{user: %{firstName: "John", lastName: "Doe"}})
      payload = Event.to_api_payload(event)

      assert payload.properties["user"]["firstName"] == "John"
      assert payload.properties["user"]["lastName"] == "Doe"
    end

    test "handles nested lists in properties" do
      event = Event.new("test", "user_123", %{tags: ["elixir", "posthog"]})
      payload = Event.to_api_payload(event)

      assert payload.properties["tags"] == ["elixir", "posthog"]
    end

    test "handles structs in properties" do
      event = Event.new("test", "user_123", %{tags: ["elixir", "posthog"], event: %__MODULE__{name: "test"}})

      payload = Event.to_api_payload(event)

      assert payload.properties["tags"] == ["elixir", "posthog"]
      assert payload.properties["event"]["name"] == "test"
    end
  end

  describe "batch_payload/1" do
    test "creates a batch payload from multiple events" do
      events = [
        Event.new("page_view", "user_123", %{page: "home"}),
        Event.new("click", "user_123", %{button: "signup"})
      ]

      batch = Event.batch_payload(events)

      assert length(batch.batch) == 2
      [first, second] = batch.batch
      assert first.event == "page_view"
      assert second.event == "click"
    end

    test "handles empty list" do
      batch = Event.batch_payload([])

      assert batch.batch == []
    end
  end
end
