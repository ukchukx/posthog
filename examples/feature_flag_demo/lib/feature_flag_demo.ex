defmodule FeatureFlagDemo do
  @moduledoc """
  A simple console application to demonstrate PostHog feature flag functionality.
  """

  def main(args) do
    # Print configuration for debugging
    api_url = System.get_env("POSTHOG_API_URL", "https://app.posthog.com")
    api_key = System.get_env("POSTHOG_API_KEY")

    IO.puts("Using API URL: #{api_url}")
    IO.puts("Using API Key: #{String.slice(api_key || "", 0, 8)}...") # Only show first 8 chars of key for security

    args
    |> parse_args()
    |> process()
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

  defp process([]) do
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

  defp process(opts) do
    flag = Keyword.get(opts, :flag)
    distinct_id = Keyword.get(opts, :distinct_id)

    if is_nil(flag) or is_nil(distinct_id) do
      IO.puts("Error: --flag and --distinct-id are both required")
      process([])
    else
      check_feature_flag(flag, distinct_id, opts)
    end
  end

  defp check_feature_flag(flag, distinct_id, opts) do
    groups = parse_json(Keyword.get(opts, :groups))
    group_properties = parse_json(Keyword.get(opts, :group_properties))
    person_properties = parse_json(Keyword.get(opts, :person_properties))

    IO.puts("Checking feature flag '#{flag}' for user '#{distinct_id}'...")

    case Posthog.feature_flag(flag, distinct_id,
           groups: groups,
           group_properties: group_properties,
           person_properties: person_properties
         ) do
      {:ok, %{enabled: true, payload: payload}} ->
        IO.puts("Feature flag '#{flag}' is ENABLED")
        IO.puts("Payload: #{inspect(payload)}")

      {:ok, %{enabled: false}} ->
        IO.puts("Feature flag '#{flag}' is DISABLED")

      {:error, %{status: 403}} ->
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

      {:error, %{status: status, body: body}} ->
        IO.puts("""
        Error: Received status #{status}
        Response body: #{inspect(body)}
        """)

      {:error, reason} ->
        IO.puts("Error checking feature flag: #{inspect(reason)}")
    end
  end

  defp parse_json(nil), do: %{}
  defp parse_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, result} -> result
      {:error, _} -> %{}
    end
  end
end
