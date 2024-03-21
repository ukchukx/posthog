defmodule Posthog.Endpoints do
  @moduledoc false
  import Posthog.Request

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

end
