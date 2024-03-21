defmodule Posthog.Request do
  @moduledoc false

  def post(path, body), do: request(url: path, json: body, method: :post)

  def patch(path, body), do: request(url: path, json: body, method: :patch)

  def get(path, query_params \\ []), do: request(url: path, params: query_params, method: :get)

  def delete(path), do: request(url: path, method: :delete)

  defp request(opts) do
    [base_url: api_url(), auth: {:bearer, api_key()}]
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: 405}} -> :ok
      {:ok, %{body: body}} -> {:ok, body}
      err -> err
    end
  end

  defp api_url do
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

  defp api_key do
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
