defmodule Posthog.Application do
  @moduledoc """
  The main application module for PostHog Elixir client.

  This module handles the application lifecycle and supervises the necessary processes
  for the PostHog client to function properly. It primarily manages the Cachex instance
  used for feature flag event deduplication.

  ## Features

  * Validates configuration before starting
  * Manages a Cachex instance for feature flag event deduplication
  * Implements LRU (Least Recently Used) caching strategy
  * Automatically prunes cache entries to maintain size limits

  ## Cache Configuration

  The Cachex instance is configured with:
  * Maximum of 50,000 entries (matching posthog-python's limit)
  * LRU (Least Recently Used) eviction policy
  * Automatic pruning every 10 seconds
  * Access tracking for LRU implementation

  ## Usage

  The application is automatically started by the Elixir runtime when included
  in your application's supervision tree. You don't need to start it manually.

  To access the cache name in your code:

      Posthog.Application.cache_name()
      # Returns: :posthog_feature_flag_cache
  """

  use Application
  import Cachex.Spec

  @cache_name :posthog_feature_flag_cache

  @doc """
  Returns the name of the Cachex instance used for feature flag event deduplication.

  ## Returns

    * `atom()` - The cache name, always `:posthog_feature_flag_cache` at the moment

  ## Examples

      iex> Posthog.Application.cache_name()
      :posthog_feature_flag_cache
  """
  def cache_name, do: @cache_name

  @doc """
  Starts the PostHog application.

  This callback is called by the Elixir runtime when the application starts.
  It performs the following tasks:
  1. Validates the PostHog configuration
  2. Sets up the Cachex instance for feature flag event deduplication
  3. Starts the supervision tree

  ## Parameters

    * `_type` - The type of start (ignored)
    * `args` - Keyword list of arguments, can include:

  ## Returns

    * `{:ok, pid()}` on successful start
    * `{:error, term()}` on failure

  ## Examples

      # Start with default configuration
      Posthog.Application.start(:normal, [])
  """
  def start(_type, args) do
    # Validate configuration before starting
    Posthog.Config.validate_config!()

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
