defmodule Posthog.Client do
  @moduledoc false
  import Posthog.Request

  def capture(event, params, timestamp) when is_bitstring(event) or is_atom(event) do
    post("/capture", build_event(event, params, timestamp))
  end

  def batch(events) when is_list(events) do
    body =
      for {event, params, timestamp} <- events do
        build_event(event, params, timestamp)
      end

    post("/capture", %{batch: body})
  end

  defp build_event(event, properties, timestamp) do
    %{event: to_string(event), properties: Map.new(properties), timestamp: timestamp}
  end

end
