defmodule Posthog.FeatureFlag do
  @moduledoc """
  Represents a PostHog feature flag with its evaluation state.

  This module provides a struct and helper functions for working with PostHog feature flags.
  Feature flags can be either boolean (on/off) or multivariate (multiple variants).

  ## Structure

  The `FeatureFlag` struct contains:
    * `name` - The name of the feature flag
    * `payload` - The payload value associated with the flag (can be any term)
    * `enabled` - The evaluation result (boolean for on/off flags, string for multivariate flags)

  ## Examples

      # Boolean feature flag
      %Posthog.FeatureFlag{
        name: "new-dashboard",
        payload: true,
        enabled: true
      }

      # Multivariate feature flag
      %Posthog.FeatureFlag{
        name: "pricing-test",
        payload: %{"price" => 99, "period" => "monthly"},
        enabled: "variant-a"
      }
  """
  defstruct [:name, :payload, :enabled]

  @typedoc """
  Represents the enabled state of a feature flag.
  Can be either a boolean for on/off flags or a string for multivariate flags.
  """
  @type variant :: binary() | boolean()

  @typedoc """
  A map of properties that can be associated with a feature flag.
  """
  @type properties :: %{optional(binary()) => term()}

  @typedoc """
  The response format from PostHog's feature flag API.
  Contains both the flag states and their associated payloads.
  """
  @type flag_response :: %{
          feature_flags: %{optional(binary()) => variant()},
          feature_flag_payloads: %{optional(binary()) => term()}
        }

  @typedoc """
  The FeatureFlag struct type.

  Fields:
    * `name` - The name of the feature flag (string)
    * `payload` - The payload value associated with the flag (any term)
    * `enabled` - The evaluation result (boolean or string)
  """
  @type t :: %__MODULE__{
          name: binary(),
          payload: term(),
          enabled: variant()
        }

  @doc """
  Creates a new FeatureFlag struct.

  ## Parameters

    * `name` - The name of the feature flag
    * `enabled` - The evaluation result (boolean or string)
    * `payload` - The payload value associated with the flag

  ## Examples

      # Create a boolean feature flag
      Posthog.FeatureFlag.new("new-dashboard", true, true)

      # Create a multivariate feature flag
      Posthog.FeatureFlag.new("pricing-test", "variant-a",
        %{"price" => 99, "period" => "monthly"})
  """
  @spec new(binary(), variant(), term()) :: t()
  def new(name, enabled, payload) do
    struct!(__MODULE__, name: name, enabled: enabled, payload: payload)
  end

  @doc """
  Checks if a feature flag is a boolean flag.

  Returns `true` if the flag is a boolean (on/off) flag, `false` if it's a multivariate flag.

  ## Examples

      flag = Posthog.FeatureFlag.new("new-dashboard", true, true)
      Posthog.FeatureFlag.boolean?(flag)
      # Returns: true

      flag = Posthog.FeatureFlag.new("pricing-test", "variant-a", %{})
      Posthog.FeatureFlag.boolean?(flag)
      # Returns: false
  """
  @spec boolean?(t()) :: boolean()
  def boolean?(%__MODULE__{enabled: value}), do: is_boolean(value)

  @doc """
  Processes a feature flag response from the PostHog API.
  Handles both v3 and v4 API response formats.

  ## Parameters

    * `response` - The raw response from the API

  ## Examples

      # v4 API response
      response = %{
        "flags" => %{
          "my-flag" => %{
            "enabled" => true,
            "variant" => nil,
            "metadata" => %{"payload" => "{\"color\": \"blue\"}"}
          }
        },
        "requestId" => "123"
      }
      Posthog.FeatureFlag.process_response(response)
      # Returns: %{
      #   flags: %{"my-flag" => %{"enabled" => true, "variant" => nil, "metadata" => %{"payload" => "{\"color\": \"blue\"}"}}},
      #   feature_flags: %{"my-flag" => true},
      #   feature_flag_payloads: %{"my-flag" => %{"color" => "blue"}},
      #   request_id: "123"
      # }

      # v3 API response
      response = %{
        "featureFlags" => %{"my-flag" => true},
        "featureFlagPayloads" => %{"my-flag" => "{\"color\": \"blue\"}"},
        "requestId" => "123"
      }
      Posthog.FeatureFlag.process_response(response)
      # Returns: %{
      #   feature_flags: %{"my-flag" => true},
      #   feature_flag_payloads: %{"my-flag" => %{"color" => "blue"}},
      #   request_id: "123"
      # }
  """
  @spec process_response(map()) :: %{
          flags: map() | nil,
          feature_flags: %{optional(binary()) => variant()},
          feature_flag_payloads: %{optional(binary()) => term()},
          request_id: binary() | nil
        }
  def process_response(%{"flags" => flags} = response) do
    feature_flags =
      Map.new(flags, fn {k, v} ->
        {k, if(v["variant"], do: v["variant"], else: v["enabled"])}
      end)

    feature_flag_payloads =
      Map.new(flags, fn {k, v} ->
        {k,
         if(v["metadata"]["payload"],
           do: decode_payload(v["metadata"]["payload"]),
           else: nil
         )}
      end)

    %{
      flags: flags,
      feature_flags: feature_flags,
      feature_flag_payloads: feature_flag_payloads,
      request_id: response["requestId"]
    }
  end

  def process_response(response) do
    %{
      flags: nil,
      feature_flags: Map.get(response, "featureFlags", %{}),
      feature_flag_payloads: decode_payloads(Map.get(response, "featureFlagPayloads", %{})),
      request_id: response["requestId"]
    }
  end

  @doc """
  Decodes a map of feature flag payloads.

  ## Parameters

    * `payloads` - Map of feature flag names to their payload values

  ## Examples

      payloads = %{
        "my-flag" => "{\"color\": \"blue\"}",
        "other-flag" => "plain-text"
      }
      Posthog.FeatureFlag.decode_payloads(payloads)
      # Returns: %{
      #   "my-flag" => %{"color" => "blue"},
      #   "other-flag" => "plain-text"
      # }
  """
  @spec decode_payloads(%{optional(binary()) => term()}) :: %{optional(binary()) => term()}
  def decode_payloads(payloads) do
    Enum.reduce(payloads, %{}, fn {k, v}, map ->
      Map.put(map, k, decode_payload(v))
    end)
  end

  @doc """
  Decodes a feature flag payload from JSON string to Elixir term.
  Returns the original payload if it's not a valid JSON string.

  ## Examples

      # JSON string payload
      Posthog.FeatureFlag.decode_payload("{\"color\": \"blue\"}")
      # Returns: %{"color" => "blue"}

      # Non-JSON string payload
      Posthog.FeatureFlag.decode_payload("plain-text")
      # Returns: "plain-text"

      # Nil payload
      Posthog.FeatureFlag.decode_payload(nil)
      # Returns: nil
  """
  @spec decode_payload(term()) :: term()
  def decode_payload(nil), do: nil

  def decode_payload(payload) when is_binary(payload) do
    case Posthog.Config.json_library().decode(payload) do
      {:ok, decoded} -> decoded
      {:error, _} -> payload
    end
  end

  def decode_payload(payload), do: payload
end
