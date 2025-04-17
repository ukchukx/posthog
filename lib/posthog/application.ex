defmodule Posthog.Application do
  @moduledoc false

  use Application
  import Cachex.Spec

  @cache_name :posthog_feature_flag_cache
  def cache_name, do: @cache_name

  def start(_type, args) do
    cache_name = Keyword.get(args, :cache_name, @cache_name)

    children = [
      # Start Cachex for feature flag event deduplication.
      # The 50,000 entries limit is the same used for `posthog-python`, but otherwise arbitrary.
      {Cachex,
       name: cache_name,
       hooks: [
         # Turns this into a LRU cache by writing to the log when an item is accessed
         hook(module: Cachex.Limit.Accessed),

         # Runs a `Cachex.prune/3` call every X seconds (see below) to keep it under the entries limit
         hook(
           module: Cachex.Limit.Scheduled,
           args: {
             50_000,
             # options for `Cachex.prune/3`
             [],
             # options for `Cachex.Limit.Scheduled`, run every 10 seconds
             [frequency: 10_000]
           }
         )
       ]}
    ]

    opts = [strategy: :one_for_one, name: Posthog.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
