# Production Task Briefings

Task briefings are refreshed by Solid Queue recurring tasks.

## Hourly Schedule

`config/recurring.yml` defines:

```yml
production:
  generate_task_briefing:
    class: Tasks::GenerateBriefingJob
    queue: background
    schedule: every hour at minute 5
```

That means production generates a new task briefing once per hour, five minutes after the hour.

## Required Production Environment

Set these environment variables on the production server:

```sh
TASK_BRIEFING_AGENT_GATEWAY_URL=http://YOUR_AGENT_TAILSCALE_IP:8642/v1/chat/completions
TASK_BRIEFING_AGENT_GATEWAY_TOKEN=REDACTED
TASK_BRIEFING_AGENT_GATEWAY_TIMEOUT=60
```

For a single-server deployment, also set:

```sh
SOLID_QUEUE_IN_PUMA=1
```

That starts the Solid Queue supervisor inside Puma. Without this, the app can serve web requests but recurring jobs will not run unless a separate jobs process is running.

The production Docker image sets these non-secret defaults:

```sh
SOLID_QUEUE_IN_PUMA=1
TASK_BRIEFING_AGENT_GATEWAY_TIMEOUT=60
```

The gateway URL and token still need to be provided by the deploy environment.

## Kamal Setup

If your Kamal config is untracked/private, add this shape to its env section:

```yml
env:
  clear:
    TASK_BRIEFING_AGENT_GATEWAY_URL: http://YOUR_AGENT_TAILSCALE_IP:8642/v1/chat/completions
    TASK_BRIEFING_AGENT_GATEWAY_TIMEOUT: 60
    SOLID_QUEUE_IN_PUMA: 1
  secret:
    - TASK_BRIEFING_AGENT_GATEWAY_TOKEN
```

Then set the secret outside git:

```sh
kamal secret set TASK_BRIEFING_AGENT_GATEWAY_TOKEN
```

After updating Kamal config/secrets, redeploy:

```sh
kamal deploy
```

For a separate worker process instead, run:

```sh
RAILS_ENV=production bin/jobs
```

## Production Verification

After deploy, manually trigger one briefing:

```sh
RAILS_ENV=production bin/rails runner 'Tasks::GenerateBriefingJob.perform_now'
```

Then confirm a briefing was saved:

```sh
RAILS_ENV=production bin/rails runner 'puts TaskBriefing.order(generated_at: :desc).first&.headline'
```

To verify recurring tasks are loaded by Solid Queue, check the production queue database for `generate_task_briefing` after the worker/supervisor starts.

## Failure Behavior

If the agent gateway is unavailable or returns invalid JSON, the app keeps working and falls back to the deterministic task briefing. The Tasks dashboard will still show the briefing when a saved one exists. (The home dashboard no longer surfaces an AI recommendation panel.)
