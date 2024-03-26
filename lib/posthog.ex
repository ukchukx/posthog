defmodule Posthog do
  @moduledoc """
  This module provides an Elixir HTTP client for Posthog.

  Example config:

      config :posthog,
        api_url: "http://posthog.example.com",
        api_key: "..."

  Optionally, you can pass in a `:json_library` key. The default JSON parser
  is Jason.
  """

  use Posthog.Client

  def version, do: Application.get_env(:posthog, :version, "1.4.9")

  def lib, do: "posthog-elixir"

  def api_url do
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

  def api_key do
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
