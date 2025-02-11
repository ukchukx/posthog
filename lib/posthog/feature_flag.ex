defmodule Posthog.FeatureFlag do
  @moduledoc false

  defstruct [:name, :value, :enabled]

  @type variant :: binary() | boolean()
  @type properties :: %{optional(binary()) => term()}
  @type flag_response :: %{
          feature_flags: %{optional(binary()) => variant()},
          feature_flag_payloads: %{optional(binary()) => term()}
        }

  @type t :: %__MODULE__{
          name: binary(),
          value: term(),
          enabled: variant()
        }

  @spec new(binary(), variant(), term()) :: t()
  def new(name, enabled, value) do
    struct!(__MODULE__, name: name, enabled: enabled, value: value)
  end

  @spec boolean?(t()) :: boolean()
  def boolean?(%__MODULE__{enabled: value}), do: is_boolean(value)
end
