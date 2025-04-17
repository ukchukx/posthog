defmodule PosthogTest do
  use ExUnit.Case, async: true
  import Mimic

  describe "feature_flag/3" do
    test "when feature flag exists, returns feature flag struct and captures event" do
      stub_with(:hackney, HackneyStub)

      HackneyStub.verify_capture(fn decoded ->
        assert decoded["event"] == "$feature_flag_called"
        assert decoded["properties"]["distinct_id"] == "user_123"
        assert decoded["properties"]["$feature_flag"] == "my-awesome-flag"
        assert decoded["properties"]["$feature_flag_response"] == true
        assert decoded["properties"]["$feature_flag_id"] == 1
        assert decoded["properties"]["$feature_flag_version"] == 23
        assert decoded["properties"]["$feature_flag_reason"] == "Matched condition set 3"
      end)

      assert {:ok, %Posthog.FeatureFlag{name: "my-awesome-flag", enabled: true, payload: "example-payload-string"}} =
               Posthog.feature_flag("my-awesome-flag", "user_123")
    end

    test "when variant flag exists, returns feature flag struct with variant and captures event" do
      stub_with(:hackney, HackneyStub)

      HackneyStub.verify_capture(fn decoded ->
        assert decoded["event"] == "$feature_flag_called"
        assert decoded["properties"]["distinct_id"] == "user_123"
        assert decoded["properties"]["$feature_flag"] == "my-multivariate-flag"
        assert decoded["properties"]["$feature_flag_response"] == "some-string-value"
        assert decoded["properties"]["$feature_flag_id"] == 3
        assert decoded["properties"]["$feature_flag_version"] == 1
        assert decoded["properties"]["$feature_flag_reason"] == "Matched condition set 1"
      end)

      assert {:ok, %Posthog.FeatureFlag{name: "my-multivariate-flag", enabled: "some-string-value", payload: nil}} =
               Posthog.feature_flag("my-multivariate-flag", "user_123")
    end

    test "Does not capture event when send_feature_flag_event is false" do
      stub_with(:hackney, HackneyStub)
      copy(Posthog.Client)
      reject(&Posthog.Client.capture/3)

      assert {:ok, %Posthog.FeatureFlag{name: "my-multivariate-flag", enabled: "some-string-value", payload: nil}} =
               Posthog.feature_flag("my-multivariate-flag", "user_123", send_feature_flag_event: false)
    end

    test "when feature flag has a json payload, will return decoded payload" do
      stub_with(:hackney, HackneyStub)

      assert Posthog.feature_flag("my-awesome-flag-2", "user_123") ==
               {:ok,
                %Posthog.FeatureFlag{
                  enabled: true,
                  name: "my-awesome-flag-2",
                  payload: %{"color" => "blue", "animal" => "hedgehog"}
                }}
    end

    test "when feature flag has an array payload, will return decoded payload" do
      stub_with(:hackney, HackneyStub)

      assert Posthog.feature_flag("array-payload", "user_123") ==
               {:ok,
                %Posthog.FeatureFlag{
                  enabled: true,
                  name: "array-payload",
                  payload: [0, 1, 2]
                }}
    end

    test "when feature flag does not have a payload, will return flag value" do
      stub_with(:hackney, HackneyStub)

      assert Posthog.feature_flag("flag-thats-not-on", "user_123") ==
               {:ok,
                %Posthog.FeatureFlag{
                  enabled: false,
                  name: "flag-thats-not-on",
                  payload: nil
                }}
    end

    test "when feature flag does not exist, returns not_found" do
      stub_with(:hackney, HackneyStubV3)

      assert Posthog.feature_flag("does-not-exist", "user_123") ==
               {:error, :not_found}
    end
  end

  describe "feature_flag_enabled?/3" do
    test "true if the feature flag is enabled" do
      stub_with(:hackney, HackneyStub)

      HackneyStub.verify_capture(fn decoded ->
        assert decoded["event"] == "$feature_flag_called"
        assert decoded["properties"]["distinct_id"] == "user_123"
        assert decoded["properties"]["$feature_flag"] == "my-awesome-flag"
        assert decoded["properties"]["$feature_flag_response"] == true
      end)

      assert Posthog.feature_flag_enabled?("my-awesome-flag", "user_123")
    end

    test "false if the feature flag is disabled" do
      stub_with(:hackney, HackneyStub)

      refute Posthog.feature_flag_enabled?("flag-thats-not-on", "user_123")
    end

    test "false if the feature flag does not exist" do
      stub_with(:hackney, HackneyStub)

      refute Posthog.feature_flag_enabled?("flag-does-not-exist", "user_123")
    end
  end

  describe "v3 - feature_flag/3" do
    test "when feature flag exists, returns feature flag struct" do
      stub_with(:hackney, HackneyStubV3)

      assert Posthog.feature_flag("my-awesome-flag", "user_123") ==
               {:ok,
                %Posthog.FeatureFlag{
                  enabled: true,
                  name: "my-awesome-flag",
                  payload: "example-payload-string"
                }}
    end

    test "when feature flag has a json payload, will return decoded payload" do
      stub_with(:hackney, HackneyStubV3)

      assert Posthog.feature_flag("my-awesome-flag-2", "user_123") ==
               {:ok,
                %Posthog.FeatureFlag{
                  enabled: true,
                  name: "my-awesome-flag-2",
                  payload: %{"color" => "blue", "animal" => "hedgehog"}
                }}
    end

    test "when feature flag has an array payload, will return decoded payload" do
      stub_with(:hackney, HackneyStubV3)

      assert Posthog.feature_flag("array-payload", "user_123") ==
               {:ok,
                %Posthog.FeatureFlag{
                  enabled: true,
                  name: "array-payload",
                  payload: [0, 1, 2]
                }}
    end

    test "when feature flag does not have a payload, will return flag value" do
      stub_with(:hackney, HackneyStubV3)

      assert Posthog.feature_flag("flag-thats-not-on", "user_123") ==
               {:ok,
                %Posthog.FeatureFlag{
                  enabled: false,
                  name: "flag-thats-not-on",
                  payload: nil
                }}
    end

    test "when feature flag does not exist, returns not_found" do
      stub_with(:hackney, HackneyStubV3)

      assert Posthog.feature_flag("does-not-exist", "user_123") ==
               {:error, :not_found}
    end
  end

  describe "v3 - feature_flag_enabled?/3" do
    test "true if the feature flag is enabled" do
      stub_with(:hackney, HackneyStubV3)

      assert Posthog.feature_flag_enabled?("my-awesome-flag", "user_123")
    end

    test "false if the feature flag is disabled" do
      stub_with(:hackney, HackneyStubV3)

      refute Posthog.feature_flag_enabled?("flag-thats-not-on", "user_123")
    end

    test "false if the feature flag does not exist" do
      stub_with(:hackney, HackneyStubV3)

      refute Posthog.feature_flag_enabled?("flag-does-not-exist", "user_123")
    end
  end
end
