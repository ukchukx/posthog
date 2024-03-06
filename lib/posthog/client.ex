defmodule Posthog.Client do
  @moduledoc false

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

    post!("/capture", body)
  end

  defp build_event(event, properties, timestamp) do
    %{event: to_string(event), properties: Map.new(properties), timestamp: timestamp}
  end

  defp post(path, %{} = body) do
    request(url: path, json: body, method: :post)
  end

  defp get(path) do
    request(url: path, method: :get)
  end

  defp request(opts) do
    [base_url: api_url(), auth: {:bearer, api_key()}]
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{body: body}} -> {:ok, body}
      err -> err
    end
  end

  defp api_url() do
    case Application.get_env(:posthog, :api_url) do
      url when is_bitstring(url) ->
        url

      term ->
        raise """
        Expected a string API URL, got: #{inspect(term)}. Set a
        URL and key in your config:

            config :posthog,
              api_url: "https://app.posthog.com",
              api_key: "my-key"
        """
    end
  end

  defp api_key() do
    case Application.get_env(:posthog, :api_key) do
      key when is_bitstring(key) ->
        key

      term ->
        raise """
        Expected a string API key, got: #{inspect(term)}. Set a
        URL and key in your config:

            config :posthog,
              api_url: "https://app.posthog.com",
              api_key: "my-key"
        """
    end
  end
end
