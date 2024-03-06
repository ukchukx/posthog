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

  def retrieve_feature_flags(project_id, opts \\ []) do
    get("/api/projects/#{project_id}/feature_flags", Keyword.take(opts, ~w[limit offset]a))
  end

  def retrieve_feature_flag_activity(project_id) do
    get("/api/projects/#{project_id}/feature_flags/activity")
  end

  def retrieve_feature_flag_evaluation_reasons(project_id) do
    get("/api/projects/#{project_id}/feature_flags/evaluation_reasons")
  end

  def retrieve_my_flags(project_id) do
    get("/api/projects/#{project_id}/feature_flags/my_flags")
  end

  def retrieve_feature_flags_for_local_evaluation(project_id) do
    get("/api/projects/#{project_id}/feature_flags/local_evaluation")
  end

  def retrieve_feature_flag(project_id, id) do
    get("/api/projects/#{project_id}/feature_flags/#{id}")
  end

  def retrieve_feature_flag_activity(project_id, id) do
    get("/api/projects/#{project_id}/feature_flags/#{id}/activity")
  end

  def retrieve_feature_flag_role_access(project_id, id, opts \\ []) do
    get("/api/projects/#{project_id}/feature_flags/#{id}/role_access", Keyword.take(opts, ~w[limit offset]a))
  end

  def retrieve_role_access(project_id, flag_id, id) do
    get("/api/projects/#{project_id}/feature_flags/#{flag_id}/role_access/#{id}")
  end

  def delete_feature_flag(project_id, id) do
    delete("/api/projects/#{project_id}/feature_flags/#{id}")
  end

  def delete_feature_flag_role_access(project_id, flag_id, id) do
    delete("/api/projects/#{project_id}/feature_flags/#{flag_id}/role_access/#{id}")
  end

  def update_feature_flag(project_id, id, %{} = body) do
    patch("/api/projects/#{project_id}/feature_flags/#{id}", body)
  end

  def create_feature_flag_user_blast_radius(project_id, %{} = body) do
    post("/api/projects/#{project_id}/feature_flags/user_blast_radius", body)
  end

  def create_feature_flag_static_cohort(project_id, id, %{} = body) do
    post("/api/projects/#{project_id}/feature_flags/#{id}/create_static_cohort_for_flag", body)
  end

  def create_feature_flag_dashboard(project_id, id, %{} = body) do
    post("/api/projects/#{project_id}/feature_flags/#{id}/dashboard", body)
  end

  def enrich_feature_flag_usage_dashboard(project_id, id, %{} = body) do
    post("/api/projects/#{project_id}/feature_flags/#{id}/enrich_usage_dashboard", body)
  end

  def create_feature_flag_role_access(project_id, flag_id, role_id) do
    post("/api/projects/#{project_id}/feature_flags/#{flag_id}/role_access", %{"role_id" => role_id})
  end

  def create_feature_flag(project_id, %{} = body) do
    post("/api/projects/#{project_id}/feature_flags", body)
  end

  defp build_event(event, properties, timestamp) do
    %{event: to_string(event), properties: Map.new(properties), timestamp: timestamp}
  end

  defp post(path, body), do: request(url: path, json: body, method: :post)

  defp patch(path, body), do: request(url: path, json: body, method: :patch)

  defp get(path, query_params \\ []), do: request(url: path, params: query_params, method: :get)

  defp delete(path), do: request(url: path, method: :delete)

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
