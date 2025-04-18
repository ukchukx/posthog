defmodule Posthog.Config do
  @moduledoc """
  Handles configuration validation and defaults for the PostHog client.

  This module validates the configuration at compile time and provides
  sensible defaults for optional values.
  """

  @app :posthog

  @doc """
  Validates and returns the API URL from the configuration.

  Raises a helpful error message if the URL is missing or invalid.
  """
  def api_url do
    case Application.get_env(@app, :api_url) do
      url when is_binary(url) and url != "" ->
        url

      nil ->
        raise """
        PostHog API URL is not configured. Please add it to your config:

            config :posthog,
              api_url: "https://us.i.posthog.com"  # or your self-hosted instance
        """

      url ->
        raise """
        Invalid PostHog API URL: #{inspect(url)}

        Expected a non-empty string URL, for example:
            config :posthog,
              api_url: "https://us.i.posthog.com"  # or your self-hosted instance
        """
    end
  end

  @doc """
  Validates and returns the API key from the configuration.

  Raises a helpful error message if the key is missing or invalid.
  """
  def api_key do
    case Application.get_env(@app, :api_key) do
      key when is_binary(key) and key != "" ->
        key

      nil ->
        raise """
        PostHog API key is not configured. Please add it to your config:

            config :posthog,
              api_key: "phc_your_project_api_key"
        """

      key ->
        raise """
        Invalid PostHog API key: #{inspect(key)}

        Expected a non-empty string API key, for example:
            config :posthog,
              api_key: "phc_your_project_api_key"
        """
    end
  end

  @doc """
  Returns whether event capture is enabled.

  Defaults to true if not configured.
  """
  def enabled_capture? do
    Application.get_env(@app, :enabled_capture, true)
  end

  @doc """
  Returns the JSON library to use for encoding/decoding.

  Defaults to Jason if not configured.
  """
  def json_library do
    Application.get_env(@app, :json_library, Jason)
  end

  @doc """
  Returns the HTTP client module to use.

  Defaults to Posthog.HTTPClient.Hackney if not configured.
  """
  def http_client do
    Application.get_env(@app, :http_client, Posthog.HTTPClient.Hackney)
  end

  @doc """
  Returns the HTTP client options.

  Defaults to:
  - timeout: 5_000 (5 seconds)
  - retries: 3
  - retry_delay: 1_000 (1 second)
  """
  def http_client_opts do
    Application.get_env(@app, :http_client_opts,
      timeout: 5_000,
      retries: 3,
      retry_delay: 1_000
    )
  end

  @doc """
  Validates the entire PostHog configuration at compile time.

  This ensures that all required configuration is present and valid
  before the application starts.
  """
  def validate_config! do
    # Validate required config
    api_url()
    api_key()

    # Validate optional config
    if json_library() != Jason do
      unless Code.ensure_loaded?(json_library()) do
        raise """
        Configured JSON library #{inspect(json_library())} is not available.

        Make sure to add it to your dependencies in mix.exs:
            defp deps do
              [{#{inspect(json_library())}, "~> x.x"}]
            end
        """
      end
    end

    # Validate HTTP client
    http_client = http_client()

    unless Code.ensure_loaded?(http_client) do
      raise """
      Configured HTTP client #{inspect(http_client)} is not available.

      Make sure to add it to your dependencies in mix.exs:
          defp deps do
            [{:hackney, "~> x.x"}]
          end
      """
    end

    :ok
  end
end
