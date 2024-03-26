defmodule Posthog.Client do
  @moduledoc false
  import Posthog.Request
  require Logger

  def capture(distinct_id, event, opts \\ []) do
    properties = Keyword.get(opts, :properties, %{})
    groups = Keyword.get(opts, :groups, %{})

    properties =
      case Map.keys(%{}) == [] do
        true -> properties
        false -> Map.put(properties, "$groups", groups)
      end

    properties =
      with true <- Keyword.get(opts, :send_feature_flags, false),
           {:ok, flags} <- get_feature_variants(distinct_id, groups) do
        flags
        |> Enum.reduce(properties, fn {feature, variant}, properties ->
          Map.put(properties, "$feature/#{feature}", variant)
        end)
        |> Map.put("$active_feature_flags", Map.keys(flags))
      else
        false ->
          properties

        {:error, err} ->
          Logger.error("[FEATURE FLAGS] Unable to get feature variants: #{inspect(err)}")
          properties
      end

    msg = %{
      distinct_id: distinct_id,
      timestamp: Keyword.get_lazy(opts, :timestamp, &timestamp/0),
      context: Keyword.get(opts, :context, %{}),
      properties: properties,
      event: event,
      uuid: Keyword.get_lazy(opts, :uuid, &UUID.uuid4/0)
    }

    send_batch([msg])
  end

  def decide(body) do
    post("/decide/?v=2", body)
  end

  def identify(distinct_id, opts \\ []) do
    msg = %{
      distinct_id: distinct_id,
      timestamp: Keyword.get_lazy(opts, :timestamp, &timestamp/0),
      context: Keyword.get(opts, :context, %{}),
      "$set": Keyword.get_lazy(opts, :properties, &default_properties/0),
      event: "$identify",
      uuid: Keyword.get_lazy(opts, :uuid, &UUID.uuid4/0)
    }

    send_batch([msg])
  end

  def page(distinct_id, url, opts \\ []) do
    properties = Keyword.get(opts, :properties, %{})

    msg = %{
      distinct_id: distinct_id,
      timestamp: Keyword.get_lazy(opts, :timestamp, &timestamp/0),
      context: Keyword.get(opts, :context, %{}),
      properties: Map.put_new(properties, :url, url),
      event: "$pageview",
      uuid: Keyword.get_lazy(opts, :uuid, &UUID.uuid4/0)
    }

    send_batch([msg])
  end

  def set(distinct_id, opts \\ []) do
    msg = %{
      distinct_id: distinct_id,
      timestamp: Keyword.get_lazy(opts, :timestamp, &timestamp/0),
      context: Keyword.get(opts, :context, %{}),
      "$set": Keyword.get(opts, :properties, %{}),
      event: "$set",
      uuid: Keyword.get_lazy(opts, :uuid, &UUID.uuid4/0)
    }

    send_batch([msg])
  end

  def set_once(distinct_id, opts \\ []) do
    msg = %{
      distinct_id: distinct_id,
      timestamp: Keyword.get_lazy(opts, :timestamp, &timestamp/0),
      context: Keyword.get(opts, :context, %{}),
      "$set_once": Keyword.get(opts, :properties, %{}),
      event: "$set_once",
      uuid: Keyword.get_lazy(opts, :uuid, &UUID.uuid4/0)
    }

    send_batch([msg])
  end

  def get_feature_variants(distinct_id, groups \\ %{}) do
    %{distinct_id: distinct_id, personal_api_key: Posthog.api_key(), groups: groups}
    |> decide()
    |> case do
      {:ok, %{"featureFlags" => flags}} -> {:ok, flags}
      err -> err
    end
  end

  def group_identify(group_type, group_key, opts \\ []) do
    msg = %{
      event: "$groupidentify",
      distinct_id: "#{group_type}_#{group_key}",
      context: Keyword.get(opts, :context, %{}),
      timestamp: Keyword.get_lazy(opts, :timestamp, &timestamp/0),
      properties: %{
        group_type: group_type,
        group_key: group_key,
        "$group_set": Keyword.get(opts, :properties, %{})
      },
      uuid: Keyword.get_lazy(opts, :uuid, &UUID.uuid4/0)
    }

    send_batch([msg])
  end

  def alias(previous_id, distinct_id, opts \\ []) do
    msg = %{
      event: "$create_alias",
      context: Keyword.get(opts, :context, %{}),
      timestamp: Keyword.get_lazy(opts, :timestamp, &timestamp/0),
      properties: %{
        distinct_id: previous_id,
        alias: distinct_id
      },
      uuid: Keyword.get_lazy(opts, :uuid, &UUID.uuid4/0)
    }

    send_batch([msg])
  end

  def load_feature_flags do
    "/api/feature_flag/?token=#{Posthog.api_key()}"
    |> get()
    |> case do
      {:ok, %{"results" => flags}} -> {:ok, Enum.filter(flags, & &1["active"])}
      err -> err
    end
  end

  def feature_enabled(key, distinct_id, opts \\ []) do
    default = Keyword.get(opts, :default, false)

    response =
      with {:ok, flags} <- load_feature_flags(),
           %{"is_simple_flag" => true} = flag <- Enum.find(flags, &(&1["key"] == key)) do
        hash(key, distinct_id) <= Map.get(flag, "rollout_percentage", 100) / 100
      else
        _ ->
          case get_feature_variants(distinct_id, Keyword.get(opts, :groups, %{})) do
            {:ok, flags} ->
              Map.get(flags, key, default)

            err ->
              Logger.error("[FEATURE FLAGS] Unable to get feature variants: #{inspect(err)}")
              default
          end
      end

    properties = %{"$feature_flag" => key, "$feature_flag_response" => response}
    capture(distinct_id, "$feature_flag_called", properties: properties)

    response
  end

  defp send_batch(batch), do: post("/batch", %{batch: batch})

  defp timestamp, do: NaiveDateTime.utc_now() |> NaiveDateTime.to_iso8601()

  defp default_properties, do: %{"$lib": Posthog.lib(), "$lib_version": Posthog.version()}

  defp hash(key, distinct_id) do
    scale = 0xFFFFFFFFFFFFFFF

    "#{key}.#{distinct_id}"
    |> then(&:crypto.hash(:sha, &1))
    |> Base.encode16(case: :lower)
    |> case do
      <<part::binary-size(15), _::binary>> -> Integer.parse(part, 16)
    end
    |> elem(0)
    |> Kernel./(scale)
  end

  defmacro __using__(_opts) do
    quote location: :keep do
      alias Posthog.Client

      defdelegate capture(distinct_id, event, opts \\ []), to: Client
      defdelegate decide(body), to: Client
      defdelegate identify(distinct_id, opts \\ []), to: Client
      defdelegate page(distinct_id, url, opts \\ []), to: Client
      defdelegate set(distinct_id, opts \\ []), to: Client
      defdelegate set_once(distinct_id, opts \\ []), to: Client
      defdelegate get_feature_variants(distinct_id, groups \\ %{}), to: Client
      defdelegate group_identify(group_type, group_key, opts \\ []), to: Client
      defdelegate alias(previous_id, distinct_id, opts \\ []), to: Client
      defdelegate load_feature_flags, to: Client
      defdelegate feature_enabled(key, distinct_id, opts \\ []), to: Client
    end
  end
end
