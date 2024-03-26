defmodule Posthog.Request do
  @moduledoc false

  def post(path, body), do: request(url: path, json: body, method: :post)

  def patch(path, body), do: request(url: path, json: body, method: :patch)

  def get(path, query_params \\ []), do: request(url: path, params: query_params, method: :get)

  def delete(path), do: request(url: path, method: :delete)

  defp request(opts) do
    default_headers = [{"user-agent", Posthog.lib() <> "/" <> Posthog.version()}]

    opts =
      opts
      |> Keyword.get(:headers, [])
      |> Keyword.merge(default_headers)
      |> then(&Keyword.put(opts, :headers, &1))
      |> add_sent_at(opts[:method])
      |> add_api_key(opts[:method])

    [base_url: Posthog.api_url(), auth: {:bearer, Posthog.api_key()}]
    |> Keyword.merge(opts)
    |> Req.new()
    |> Req.request()
    |> case do
      {:ok, %{status: 405}} -> :ok
      {:ok, %{body: body}} -> {:ok, body}
      err -> err
    end
  end

  defp add_sent_at(opts, :post) do
    case opts[:json] do
      nil ->
        opts

      body ->
        now = NaiveDateTime.utc_now()
        body = Map.put(body, :sentAt, NaiveDateTime.to_iso8601(now))
        Keyword.put(opts, :body, body)
    end
  end

  defp add_sent_at(opts, _), do: opts

  defp add_api_key(opts, :post) do
    case opts[:json] do
      nil -> opts
      body -> Keyword.put(opts, :body, Map.put(body, :api_key, Posthog.api_key()))
    end
  end

  defp add_api_key(opts, _), do: opts
end
