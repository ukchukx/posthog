defmodule Posthog.ClientTest do
  use ExUnit.Case, async: true
  import Mimic

  # Make private functions testable
  @moduletag :capture_log
  import Posthog.Client, only: [], warn: false
  import Mimic
  alias Posthog.Client

  describe "build_event/3" do
    test "includes all base properties" do
      event = Client.build_event("test_event", "user_123", %{}, "2024-03-20", "fake-uuid")

      assert event.event == "test_event"
      assert event.distinct_id == "user_123"
      assert event.timestamp == "2024-03-20"
      assert event.uuid == "fake-uuid"
      assert event.properties["$lib"] == "posthog-elixir"
      assert event.properties["$lib_version"] == Mix.Project.config()[:version]
    end

    test "generates valid uuid if not passed in" do
      event = Client.build_event("test_event", "user_123", %{}, "2024-03-20")

      # Don't assert on the value of the uuid, just that it's a valid-ish uuid
      assert event.uuid
      assert is_binary(event.uuid)
      assert String.length(event.uuid) == 36
    end

    test "includes library information in properties" do
      event = Client.build_event("test_event", "user_123", %{}, "2024-03-20")

      assert event.event == "test_event"
      assert event.distinct_id == "user_123"
      assert event.timestamp == "2024-03-20"

      assert event.properties["$lib"] == "posthog-elixir"
      assert event.properties["$lib_version"] == Mix.Project.config()[:version]
    end

    test "merges user properties with library properties" do
      event =
        Client.build_event(
          "test_event",
          "user_123",
          %{"user_id" => 123, "custom" => "value"},
          "2024-03-20"
        )

      assert event.properties["$lib"] == "posthog-elixir"
      assert event.properties["$lib_version"] == Mix.Project.config()[:version]

      assert event.properties["user_id"] == 123
      assert event.properties["custom"] == "value"
    end

    test "converts atom event names to strings" do
      event = Client.build_event(:test_event, "user_123", %{}, "2024-03-20")

      assert event.event == "test_event"
      assert event.distinct_id == "user_123"
      assert event.timestamp == "2024-03-20"
    end

    test "user properties override library properties" do
      event =
        Client.build_event(
          "test_event",
          "user_123",
          %{"$lib" => "custom", "$lib_version" => "1.0.0"},
          "2024-03-20"
        )

      assert event.properties["$lib"] == "custom"
      assert event.properties["$lib_version"] == "1.0.0"
    end

    test "properties are converted from atom keys to string keys" do
      event =
        Client.build_event(
          "test_event",
          "user_123",
          %{
            foo: "bar",
            nested: %{
              atom_key: 123,
              list: [1, 2, 3],
              keyword_list: [a: 1, b: 2]
            }
          },
          "2024-03-20"
        )

      assert event.properties == %{
               "foo" => "bar",
               "$lib" => "posthog-elixir",
               "$lib_version" => Mix.Project.config()[:version],
               "nested" => %{
                 "atom_key" => 123,
                 "list" => [1, 2, 3],
                 "keyword_list" => %{"a" => 1, "b" => 2}
               }
             }
    end
  end

  describe "capture/3" do
    test "captures an event with basic properties" do
      stub(:hackney, :post, fn url, headers, body, _opts ->
        assert url == "https://us.posthog.com/capture"
        assert headers == [{"content-type", "application/json"}]
        decoded = Jason.decode!(body)
        assert decoded["event"] == "test_event"
        assert decoded["distinct_id"] == "user_123"
        {:ok, 200, [], "ref"}
      end)

      stub(:hackney, :body, fn "ref" -> {:ok, "{}"} end)

      assert {:ok, %{status: 200}} = Client.capture("test_event", "user_123")
    end

    test "captures an event with timestamp" do
      timestamp = "2024-03-20T12:00:00Z"

      stub(:hackney, :post, fn _url, _headers, body, _opts ->
        decoded = Jason.decode!(body)
        assert decoded["timestamp"] == timestamp
        {:ok, 200, [], "ref"}
      end)

      stub(:hackney, :body, fn "ref" -> {:ok, "{}"} end)

      assert {:ok, %{status: 200}} =
               Client.capture("test_event", "user_123", %{}, timestamp: timestamp)
    end

    test "captures an event with custom headers" do
      stub(:hackney, :post, fn _url, headers, _body, _opts ->
        assert Enum.sort(headers) ==
                 Enum.sort([
                   {"content-type", "application/json"},
                   {"x-forwarded-for", "127.0.0.1"}
                 ])

        {:ok, 200, [], "ref"}
      end)

      stub(:hackney, :body, fn "ref" -> {:ok, "{}"} end)

      assert {:ok, %{status: 200}} =
               Client.capture("test_event", "user_123", %{},
                 headers: [{"x-forwarded-for", "127.0.0.1"}]
               )
    end
  end

  describe "enabled_capture" do
    test "when enabled_capture is false, capture returns success without making request" do
      Application.put_env(:posthog, :enabled_capture, false)
      on_exit(fn -> Application.delete_env(:posthog, :enabled_capture) end)

      assert Client.capture("test_event", "user_123") ==
               {:ok, %{status: 200, headers: [], body: nil}}
    end

    test "when enabled_capture is false, batch returns success without making request" do
      Application.put_env(:posthog, :enabled_capture, false)
      on_exit(fn -> Application.delete_env(:posthog, :enabled_capture) end)

      events = [
        {"test_event", %{distinct_id: "user_123"}, nil},
        {"another_event", %{distinct_id: "user_123"}, nil}
      ]

      assert Client.batch(events, []) ==
               {:ok, %{status: 200, headers: [], body: nil}}
    end

    test "when enabled_capture is false, feature_flags still works" do
      Application.put_env(:posthog, :enabled_capture, false)
      on_exit(fn -> Application.delete_env(:posthog, :enabled_capture) end)

      # Stub FF HTTP request
      stub_with(:hackney, HackneyStub)

      assert {:ok, %{feature_flags: flags}} = Client.feature_flags("user_123", [])
      assert flags["my-awesome-flag"] == true
    end
  end
end
