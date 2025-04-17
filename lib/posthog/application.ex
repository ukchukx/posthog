defmodule Posthog.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start Cachex for feature flag event deduplication.
      # The 50,000 entries limit is the same used for posthog-python, but otherwise arbitrary.
      {Cachex, name: :posthog_feature_flag_cache, limit: 50_000, policy: Cachex.Policy.LRW}
    ]

    opts = [strategy: :one_for_one, name: Posthog.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
