defmodule Posthog.Application do
  @moduledoc false

  use Application

  @cache_name :posthog_feature_flag_cache
  def cache_name, do: @cache_name

  def start(_type, args) do
    cache_name = Keyword.get(args, :cache_name, @cache_name)

    children = [
      # Start Cachex for feature flag event deduplication.
      # The 50,000 entries limit is the same used for posthog-python, but otherwise arbitrary.
      {Cachex, name: cache_name, limit: 50_000, policy: Cachex.Policy.LRU}
    ]

    opts = [strategy: :one_for_one, name: Posthog.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
