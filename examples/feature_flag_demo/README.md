# Feature Flag Demo

A simple console application to demonstrate PostHog feature flag functionality.

## Setup

1. Install dependencies:
   ```bash
   bin/setup
   ```

2. Set your PostHog API key and URL:
   ```bash
   export POSTHOG_API_KEY="your_project_api_key"
   export POSTHOG_API_URL="https://app.posthog.com"  # Or your self-hosted instance
   ```

## Usage

Run the demo with:
```bash
mix run run.exs --flag FLAG_NAME --distinct-id USER_ID [options]
```

Options:
- `--flag FLAG_NAME` - The name of the feature flag to check
- `--distinct-id USER_ID` - The distinct ID of the user
- `--groups GROUPS` - JSON string of group properties (optional)
- `--group_properties PROPERTIES` - JSON string of group properties (optional)
- `--person_properties PROPERTIES` - JSON string of person properties (optional)

Example:
```bash
mix run run.exs --flag "test-flag" --distinct-id "user123"
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
