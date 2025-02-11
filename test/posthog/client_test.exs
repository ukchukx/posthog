defmodule Posthog.ClientTest do
  use ExUnit.Case, async: true

  # Make private functions testable
  @moduletag :capture_log
  import Posthog.Client, only: [], warn: false
  alias Posthog.Client

  describe "build_event/3" do
    test "includes library information in properties" do
      event = Client.build_event("test_event", %{}, "2024-03-20")

      assert event.event == "test_event"
      assert event.timestamp == "2024-03-20"

      assert event.properties["$lib"] == "posthog-elixir"
      assert event.properties["$lib_version"] == Mix.Project.config()[:version]
    end

    test "merges user properties with library properties" do
      event =
        Client.build_event(
          "test_event",
          %{"user_id" => 123, "custom" => "value"},
          "2024-03-20"
        )

      assert event.properties["$lib"] == "posthog-elixir"
      assert event.properties["$lib_version"] == Mix.Project.config()[:version]

      assert event.properties["user_id"] == 123
      assert event.properties["custom"] == "value"
    end

    test "converts atom event names to strings" do
      event = Client.build_event(:test_event, %{}, "2024-03-20")

      assert event.event == "test_event"
    end

    test "user properties override library properties" do
      event =
        Client.build_event(
          "test_event",
          %{"$lib" => "custom", "$lib_version" => "1.0.0"},
          "2024-03-20"
        )

      assert event.properties["$lib"] == "custom"
      assert event.properties["$lib_version"] == "1.0.0"
    end
  end
end
