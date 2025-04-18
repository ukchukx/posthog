defmodule FeatureFlagDemo do
  @moduledoc """
  A simple console application to demonstrate PostHog feature flag functionality.
  """

  @default_api_url "https://app.posthog.com"

  def main(args) do
    print_info(:config)
    args
    |> parse_args()
    |> process()
  end

  defp print_info(:config) do
    api_url = System.get_env("POSTHOG_API_URL", @default_api_url)
    api_key = System.get_env("POSTHOG_API_KEY")

    IO.puts("Using API URL: #{api_url}")
    IO.puts("Using API Key: #{String.slice(api_key || "", 0, 8)}...")
  end

  defp print_info(:usage) do
    IO.puts("""
    Usage: mix run run.exs --flag FLAG_NAME --distinct-id USER_ID [options]

    Options:
      --flag FLAG_NAME              The name of the feature flag to check
      --distinct-id USER_ID         The distinct ID of the user
      --groups GROUPS               JSON string of group properties (optional)
      --group_properties PROPERTIES JSON string of group properties (optional)
      --person_properties PROPERTIES JSON string of person properties (optional)
    """)
  end

  defp parse_args(args) do
    {opts, _, _} = OptionParser.parse(args,
      switches: [
        flag: :string,
        distinct_id: :string,
        groups: :string,
        group_properties: :string,
        person_properties: :string
      ],
      aliases: [
        d: :distinct_id
      ]
    )
    opts
  end

  defp process([]), do: print_info(:usage)

  defp process([flag: flag, distinct_id: distinct_id] = opts) do
    IO.puts("Checking feature flag '#{flag}' for user '#{distinct_id}'...")

    with {:ok, response} <- call_feature_flag(flag, distinct_id, opts),
         {:ok, message} <- format_response(flag, response) do
      IO.puts(message)
    else
      {:error, %{status: 403}} -> print_auth_error()
      {:error, %{status: status, body: body}} -> IO.puts("Error: Received status #{status}\nResponse body: #{inspect(body)}")
      {:error, reason} -> IO.puts("Error: #{inspect(reason)}")
    end
  end

  defp process(_), do: print_info(:usage)

  defp call_feature_flag(flag, distinct_id, opts) do
    Posthog.feature_flag(flag, distinct_id,
      groups: parse_json(opts[:groups]),
      group_properties: parse_json(opts[:group_properties]),
      person_properties: parse_json(opts[:person_properties])
    )
  end

  defp format_response(flag, %{enabled: enabled, payload: payload}) do
    message = case enabled do
      true -> "Feature flag '#{flag}' is ENABLED"
      false -> "Feature flag '#{flag}' is DISABLED"
      variant when is_binary(variant) -> "Feature flag '#{flag}' is ENABLED with variant: #{variant}"
    end

    message = if payload, do: message <> "\nPayload: #{inspect(payload)}", else: message
    {:ok, message}
  end

  defp print_auth_error do
    IO.puts("""
    Error: Authentication failed (403 Forbidden)

    Please check that:
    1. Your POSTHOG_API_KEY is set correctly
    2. Your POSTHOG_API_URL is set correctly (if using a self-hosted instance)
    3. The API key has the necessary permissions
    4. Your local PostHog instance is running and accessible

    You can set these environment variables:
    export POSTHOG_API_KEY="your_project_api_key"
    export POSTHOG_API_URL="http://localhost:8000"  # Note: no trailing slash
    """)
  end

  defp parse_json(value) do
    case value do
      nil -> nil
      "" -> nil
      json when is_binary(json) -> Jason.decode!(json)
      other -> other
    end
  end
end
