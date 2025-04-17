## 1.0.0 - 2025-04-??

### Big Release

`posthog-elixir` is now officially stable and running on v1. There are some breaking changes and some general improvements. Check [MIGRATION.md](./MIGRATION.md#v0-v1) for a guide on how to migrate.

### What's changed

- Elixir v1.14+ is now a requirement
- Feature Flags now return a key called `payload` rather than `value` to better align with the other SDKs
- PostHog now requires you to initialize `Posthog.Application` alongside your supervisor tree. This is required because of our `Cachex` system to properly track your FF usage.
  - We'll also include local evaluation in the near term, which will also require a GenServer, therefore, requiring us to use a Supervisor.
- Added `enabled_capture` configuration option to disable PostHog tracking in development/test environments
- `Posthog.capture` now requires `distinct_id` as a required second argument

## 0.4.4 - 2025-04-14

Fix inconsistent docs for properties - [#13]

## 0.4.3 - 2025-04-14

Improve docs setup - [#12]

## 0.4.2 - 2025-03-27

Allow `atom()` property keys - [#11]

## 0.4.1 - 2025-03-12

Fix feature flags broken implementation - [#10]

## 0.4.0 - 2025-02-11

Documentation + OTP/Elixir version bumps

## 0.3.0 - 2025-01-09

- Initial feature flags implementation (#7)

## 0.2.0 - 2024-05-04

- Allow extra headers (#3)

## 0.1.0 - 2020-06-06

- Initial release
