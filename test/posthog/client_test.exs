defmodule Posthog.ClientTest do
  # Async tests are not supported in this file
  # because we're using the process state to track the number of times
  # a function is called.
  use ExUnit.Case, async: false
  import Mimic

  # Make private functions testable
  @moduletag :capture_log
  import Posthog.Client, only: [], warn: false
  alias Posthog.Client

  setup do
    # Clear the cache before each test
    Cachex.clear(Posthog.Application.cache_name())
    stub_with(:hackney, HackneyStub)
    {:ok, _} = HackneyStub.State.start_link([])
    :ok
  end

  describe "feature_flag/3" do
    test "when feature flag exists, returns feature flag struct and captures event" do
      stub_with(:hackney, HackneyStub)

      HackneyStub.verify_capture(fn decoded ->
        assert decoded["event"] == "$feature_flag_called"
        assert decoded["distinct_id"] == "user_123"
        assert decoded["properties"]["$feature_flag"] == "my-awesome-flag"
        assert decoded["properties"]["$feature_flag_response"] == true
        assert decoded["properties"]["$feature_flag_id"] == 1
        assert decoded["properties"]["$feature_flag_version"] == 23
        assert decoded["properties"]["$feature_flag_reason"] == "Matched condition set 3"

        assert decoded["properties"]["$feature_flag_request_id"] ==
                 "0f801b5b-0776-42ca-b0f7-8375c95730bf"
      end)

      assert {:ok,
              %Posthog.FeatureFlag{
                name: "my-awesome-flag",
                enabled: true,
                payload: "example-payload-string"
              }} = Client.feature_flag("my-awesome-flag", "user_123")
    end

    test "when variant flag exists, returns feature flag struct with variant and captures event" do
      stub_with(:hackney, HackneyStub)

      HackneyStub.verify_capture(fn decoded ->
        assert decoded["event"] == "$feature_flag_called"
        assert decoded["distinct_id"] == "user_123"
        assert decoded["properties"]["$feature_flag"] == "my-multivariate-flag"
        assert decoded["properties"]["$feature_flag_response"] == "some-string-value"
        assert decoded["properties"]["$feature_flag_id"] == 3
        assert decoded["properties"]["$feature_flag_version"] == 1
        assert decoded["properties"]["$feature_flag_reason"] == "Matched condition set 1"

        assert decoded["properties"]["$feature_flag_request_id"] ==
                 "0f801b5b-0776-42ca-b0f7-8375c95730bf"
      end)

      assert {:ok,
              %Posthog.FeatureFlag{
                name: "my-multivariate-flag",
                enabled: "some-string-value",
                payload: nil
              }} = Client.feature_flag("my-multivariate-flag", "user_123")
    end

    test "does not capture feature_flag_called event twice for same distinct_id and flag key" do
      # Initialize the counter in the process dictionary
      Process.put(:capture_count, 0)

      stub_with(:hackney, HackneyStub)
      copy(Client)

      stub(Client, :capture, fn "$feature_flag_called", _distinct_id, properties, _opts ->
        # Increment the counter in the process dictionary
        Process.put(:capture_count, Process.get(:capture_count) + 1)

        assert properties["$feature_flag"] == "my-multivariate-flag"
        assert properties["$feature_flag_response"] == "some-string-value"
        assert properties["$feature_flag_id"] == 3
        assert properties["$feature_flag_version"] == 1
        assert properties["$feature_flag_reason"] == "Matched condition set 1"
        assert properties["$feature_flag_request_id"] == "0f801b5b-0776-42ca-b0f7-8375c95730bf"

        {:ok, %{status: 200}}
      end)

      # First call
      assert {:ok,
              %Posthog.FeatureFlag{
                name: "my-multivariate-flag",
                enabled: "some-string-value",
                payload: nil
              }} = Client.feature_flag("my-multivariate-flag", "user_123")

      # Second call with same parameters
      assert {:ok,
              %Posthog.FeatureFlag{
                name: "my-multivariate-flag",
                enabled: "some-string-value",
                payload: nil
              }} = Client.feature_flag("my-multivariate-flag", "user_123")

      # Verify capture was only called once
      assert Process.get(:capture_count) == 1
    end

    test "captures feature_flag_called event for different user IDs or flag keys" do
      # Initialize the counter in the process dictionary
      Process.put(:capture_count, 0)

      # Keep track of seen combinations
      Process.put(:seen_combinations, MapSet.new())

      stub_with(:hackney, HackneyStub)
      copy(Client)

      stub(Client, :capture, fn "$feature_flag_called", distinct_id, properties, _opts ->
        # Increment the counter in the process dictionary
        Process.put(:capture_count, Process.get(:capture_count) + 1)

        # Add this combination to seen combinations
        Process.put(
          :seen_combinations,
          MapSet.put(Process.get(:seen_combinations), {
            distinct_id,
            properties["$feature_flag"],
            properties["$feature_flag_response"]
          })
        )

        # Verify properties are correct regardless of order
        assert distinct_id in ["user_123", "user_456"]
        assert properties["$feature_flag"] in ["my-multivariate-flag", "my-awesome-flag"]
        assert properties["$feature_flag_response"] in [true, "some-string-value"]
        assert properties["$feature_flag_id"] in [1, 3]
        assert properties["$feature_flag_version"] in [1, 23]

        assert properties["$feature_flag_reason"] in [
                 "Matched condition set 1",
                 "Matched condition set 3"
               ]

        assert properties["$feature_flag_request_id"] == "0f801b5b-0776-42ca-b0f7-8375c95730bf"

        {:ok, %{status: 200}}
      end)

      # Call feature_flag with different combinations
      assert {:ok,
              %Posthog.FeatureFlag{
                name: "my-multivariate-flag",
                enabled: "some-string-value",
                payload: nil
              }} = Client.feature_flag("my-multivariate-flag", "user_123")

      assert {:ok,
              %Posthog.FeatureFlag{
                name: "my-multivariate-flag",
                enabled: "some-string-value",
                payload: nil
              }} = Client.feature_flag("my-multivariate-flag", "user_456")

      assert {:ok,
              %Posthog.FeatureFlag{
                name: "my-awesome-flag",
                enabled: true,
                payload: "example-payload-string"
              }} = Client.feature_flag("my-awesome-flag", "user_123")

      # Verify we got all three unique combinations
      assert Process.get(:capture_count) == 3
      assert MapSet.size(Process.get(:seen_combinations)) == 3
    end

    test "does not capture event when send_feature_flag_event is false" do
      stub_with(:hackney, HackneyStub)
      copy(Client)
      reject(&Client.capture/3)

      assert {:ok,
              %Posthog.FeatureFlag{
                name: "my-multivariate-flag",
                enabled: "some-string-value",
                payload: nil
              }} =
               Client.feature_flag("my-multivariate-flag", "user_123",
                 send_feature_flag_event: false
               )
    end

    test "when feature flag has a json payload, will return decoded payload" do
      stub_with(:hackney, HackneyStub)

      assert Client.feature_flag("my-awesome-flag-2", "user_123") ==
               {:ok,
                %Posthog.FeatureFlag{
                  enabled: true,
                  name: "my-awesome-flag-2",
                  payload: %{"color" => "blue", "animal" => "hedgehog"}
                }}
    end

    test "when feature flag has an array payload, will return decoded payload" do
      stub_with(:hackney, HackneyStub)

      assert Client.feature_flag("array-payload", "user_123") ==
               {:ok,
                %Posthog.FeatureFlag{
                  enabled: true,
                  name: "array-payload",
                  payload: [0, 1, 2]
                }}
    end

    test "when feature flag does not have a payload, will return flag value" do
      stub_with(:hackney, HackneyStub)

      assert Client.feature_flag("flag-thats-not-on", "user_123") ==
               {:ok,
                %Posthog.FeatureFlag{
                  enabled: false,
                  name: "flag-thats-not-on",
                  payload: nil
                }}
    end

    test "when feature flag does not exist, returns not_found" do
      stub_with(:hackney, HackneyStubV3)

      assert Client.feature_flag("does-not-exist", "user_123") ==
               {:error, :not_found}
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
