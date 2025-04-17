# PostHog Feature Flag Demo

A simple console application that demonstrates how to use PostHog's feature flag functionality.

## Setup

1. Make sure you have the required environment variables set:

```bash
export POSTHOG_API_KEY="your_project_api_key"
export POSTHOG_API_URL="https://us.posthog.com"  # or `eu.posthog.com` or your self-hosted instance URL
```

2. Install dependencies:

```bash
mix deps.get
```

## Usage

Basic usage:

```bash
mix run run.exs --flag "your-feature-flag" --distinct-id "user123"
```

With group properties:

```bash
mix run run.exs --flag "your-feature-flag" --distinct-id "user123" \
  --groups '{"company": "company123"}' \
  --group_properties '{"company": {"industry": "tech"}}' \
  --person_properties '{"email": "user@example.com"}'
```

## Example Output

If the feature flag is enabled:

```bash
Feature flag 'your-feature-flag' is ENABLED
Payload: true
```

If the feature flag is disabled:

```bash
Feature flag 'your-feature-flag' is DISABLED
```
