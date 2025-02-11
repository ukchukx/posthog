defmodule Posthog.Client do
  @moduledoc false
  @app :posthog

  @type headers :: [{binary(), binary()}]
  @type response :: %{status: pos_integer(), headers: headers(), body: map() | nil}
  @type event :: atom() | binary()
  @type properties :: %{optional(String.t()) => term()}
  @type timestamp :: String.t()
  @type opts :: [
          headers: headers(),
          groups: map(),
          group_properties: map(),
          person_properties: map(),
          timestamp: timestamp()
        ]

  @lib_version Mix.Project.config()[:version]
  @lib_name "posthog-elixir"

  @spec headers(headers()) :: headers()
  defp headers(additional_headers \\ []) do
    Enum.concat(additional_headers || [], [{"content-type", "application/json"}])
  end

  @spec capture(event(), properties(), opts() | timestamp()) ::
          {:ok, response()} | {:error, response() | term()}
  def capture(event, params, opts) when is_list(opts) do
    post!("/capture", build_event(event, params, opts[:timestamp]), headers(opts[:headers]))
  end

  def capture(event, params, timestamp) when is_bitstring(event) or is_atom(event) do
    post!("/capture", build_event(event, params, timestamp), headers())
  end

  @spec batch([{event(), properties(), timestamp()}], opts() | any(), headers()) ::
          {:ok, response()} | {:error, response() | term()}
  def batch(events, opts) when is_list(opts) do
    batch(events, opts, headers(opts[:headers]))
  end

  def batch(events, _opts, headers) do
    body = for {event, params, timestamp} <- events, do: build_event(event, params, timestamp)

    post!("/capture", %{batch: body}, headers)
  end

  @spec feature_flags(binary(), opts()) ::
          {:ok, Posthog.FeatureFlag.flag_response()} | {:error, response() | term()}
  def feature_flags(distinct_id, opts) do
    body =
      opts
      |> Keyword.take(~w[groups group_properties person_properties]a)
      |> Enum.reduce(%{distinct_id: distinct_id}, fn {k, v}, map -> Map.put(map, k, v) end)

    case post!("/decide", body, headers(opts[:headers])) do
      {:ok, %{body: body}} ->
        flag_fields = %{
          feature_flags: body["featureFlags"],
          feature_flag_payloads:
            body["featureFlagPayloads"]
            |> Enum.reduce(%{}, fn {k, v}, map -> Map.put(map, k, Jason.decode!(v)) end)
        }

        {:ok, flag_fields}

      err ->
        err
    end
  end

  @spec build_event(event(), properties(), timestamp()) :: map()
  def build_event(event, properties, timestamp) do
    properties = Map.merge(lib_properties(), Map.new(properties))
    %{event: to_string(event), properties: properties, timestamp: timestamp}
  end

  @spec post!(binary(), map(), headers()) :: {:ok, response()} | {:error, response() | term()}
  defp post!(path, %{} = body, headers) do
    body =
      body
      |> Map.put(:api_key, api_key())
      |> encode(json_library())

    url = api_url() <> path <> "?v=#{api_version()}"

    :hackney.post(url, headers, body)
    |> handle()
  end

  @spec handle(tuple()) :: {:ok, response()} | {:error, response() | term()}
  defp handle({:ok, status, _headers, _ref} = resp) when div(status, 100) == 2 do
    {:ok, to_response(resp)}
  end

  defp handle({:ok, _status, _headers, _ref} = resp) do
    {:error, to_response(resp)}
  end

  defp handle({:error, _} = result) do
    result
  end

  @spec to_response({:ok, pos_integer(), headers(), reference()}) :: response()
  defp to_response({_, status, headers, ref}) do
    response = %{status: status, headers: headers, body: nil}

    with {:ok, body} <- :hackney.body(ref),
         {:ok, json} <- json_library().decode(body) do
      %{response | body: json}
    else
      _ -> response
    end
  end

  @spec api_url() :: binary()
  defp api_url do
    case Application.get_env(@app, :api_url) do
      url when is_bitstring(url) ->
        url

      term ->
        raise """
        Expected a string API URL, got: #{inspect(term)}. Set a
        URL and key in your config:

            config :posthog,
              api_url: "https://posthog.example.com",
              api_key: "my-key"
        """
    end
  end

  @spec api_key() :: binary()
  defp api_key do
    case Application.get_env(@app, :api_key) do
      key when is_bitstring(key) ->
        key

      term ->
        raise """
        Expected a string API key, got: #{inspect(term)}. Set a
        URL and key in your config:

            config :posthog,
              api_url: "https://posthog.example.com",
              api_key: "my-key"
        """
    end
  end

  @spec encode(term(), module()) :: iodata()
  defp encode(data, Jason), do: Jason.encode_to_iodata!(data)
  defp encode(data, library), do: library.encode!(data)

  @spec json_library() :: module()
  defp json_library do
    Application.get_env(@app, :json_library, Jason)
  end

  @spec api_version() :: pos_integer()
  defp api_version do
    Application.get_env(@app, :version, 3)
  end

  @spec lib_properties() :: map()
  defp lib_properties do
    %{
      "$lib" => @lib_name,
      "$lib_version" => @lib_version
    }
  end
end
