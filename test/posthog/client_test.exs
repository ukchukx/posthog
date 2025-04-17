defmodule Posthog.ClientTest do
  use ExUnit.Case, async: true
  import Mimic

  # Make private functions testable
  @moduletag :capture_log
  import Posthog.Client, only: [], warn: false
  import Mimic
  alias Posthog.Client

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
