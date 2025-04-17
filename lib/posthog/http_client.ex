defmodule Posthog.HTTPClient do
  @moduledoc """
  Behaviour for HTTP client implementations.

  This allows for easy swapping of HTTP clients and better testability.
  """

  @type headers :: [{binary(), binary()}]
  @type response :: %{status: pos_integer(), headers: headers(), body: map() | nil}
  @type body :: iodata() | binary()
  @type url :: binary()

  @doc """
  Makes a POST request to the given URL with the specified body and headers.

  Returns `{:ok, response}` on success or `{:error, reason}` on failure.
  """
  @callback post(url(), body(), headers(), keyword()) :: {:ok, response()} | {:error, term()}
end

defmodule Posthog.HTTPClient.Hackney do
  @moduledoc """
  Hackney-based implementation of the Posthog.HTTPClient behaviour.
  """

  @behaviour Posthog.HTTPClient

  @default_timeout 5_000
  @default_retries 3
  @default_retry_delay 1_000

  @impl true
  def post(url, body, headers, opts \\ []) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    retries = Keyword.get(opts, :retries, @default_retries)
    retry_delay = Keyword.get(opts, :retry_delay, @default_retry_delay)

    do_post(url, body, headers, timeout, retries, retry_delay)
  end

  defp do_post(url, body, headers, timeout, retries, retry_delay) do
    case :hackney.post(url, headers, body, []) do
      {:ok, status, _headers, _ref} = resp when div(status, 100) == 2 ->
        {:ok, to_response(resp)}

      {:ok, _status, _headers, _ref} = resp ->
        {:error, to_response(resp)}

      {:error, _reason} when retries > 0 ->
        Process.sleep(retry_delay)
        do_post(url, body, headers, timeout, retries - 1, retry_delay)

      {:error, _reason} = error ->
        error
    end
  end

  defp to_response({_, status, headers, ref}) do
    response = %{status: status, headers: headers, body: nil}

    with {:ok, body} <- :hackney.body(ref),
         {:ok, json} <- Posthog.Config.json_library().decode(body) do
      %{response | body: json}
    else
      _ -> response
    end
  end
end
