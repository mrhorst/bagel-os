# Production observability & self-healing loop

How we see what production is doing, and how an autonomous agent turns errors
into reviewed, deployed fixes.

There are two layers, and they answer different questions:

| Layer | Question it answers | Tool | Retention |
| --- | --- | --- | --- |
| **Logs** | "What was the app doing around 14:32?" | `bin/prod-logs` (Kamal/SSH) | Ephemeral — rotates, lost on redeploy |
| **Errors** | "What is broken, how often, in which release, with what backtrace?" | GlitchTip (self-hosted) | Durable, deduplicated, searchable, alertable |

Logs are for ad-hoc investigation. **Errors are the signal the automation runs
on** — deduplicated issues with a stable fingerprint, backtrace, and release tag
are a far better trigger than a raw log firehose.

---

## 1. Reading production logs

The app logs to STDOUT (`config/environments/production.rb`); Docker captures it
and Kamal streams it over SSH.

```sh
bin/prod-logs                 # follow live logs
bin/prod-logs -n 500          # last 500 lines, then follow
bin/prod-logs --grep Error    # only matching lines
bin/prod-logs --once -n 200   # dump last 200 and exit
```

This is `kamal app logs` under the hood (the `logs` alias also works). Container
logs are **ephemeral** — for anything you need to keep or alert on, use GlitchTip.

---

## 2. Error tracking — self-hosted GlitchTip

We use **GlitchTip** (Sentry-API-compatible) running as a Kamal accessory stack
on the same Hetzner box, so **no production data ever leaves our infrastructure**.
The Rails app reports via the standard `sentry-ruby` / `sentry-rails` SDK.

### App side (already wired)

- `config/initializers/sentry.rb` — inert unless `SENTRY_DSN` is set, so dev/test
  never phone home. Tags each event with the release (`KAMAL_VERSION`), excludes
  routing/404/CSRF noise, and runs `Observability::SentryScrubber`.
- **Privacy:** `send_default_pii = false` plus the scrubber re-applies the app's
  `filter_parameters` and strips auth/cookie headers. Production carries real
  restaurant data — keep both layers. See `app/services/observability/sentry_scrubber.rb`.

### Bringing GlitchTip up (one-time)

GlitchTip lives in its own Kamal config, `config/deploy.glitchtip.yml`, isolated
from the app deploy so it can never break `kamal deploy`. It is a **template** —
confirm image tags/env against the GlitchTip docs and pin `GLITCHTIP_IMAGE` first.

1. Export the deploy env (same SSH/registry vars as the app deploy) plus:

   | Var | Purpose |
   | --- | --- |
   | `GLITCHTIP_SECRET_KEY` | Django secret — `bin/rails secret` or `openssl rand -hex 32` |
   | `GLITCHTIP_POSTGRES_PASSWORD` | GlitchTip's own Postgres password |
   | `GLITCHTIP_DOMAIN` | e.g. `http://localhost:8080` (tunnelled) or a real subdomain |
   | `GLITCHTIP_IMAGE` | pinned tag, e.g. `glitchtip/glitchtip:v4.x` |

   Secrets are read from `.kamal/secrets.glitchtip` (no literal values tracked).

2. Boot and initialize:

   ```sh
   bin/kamal accessory boot all -c config/deploy.glitchtip.yml
   bin/kamal accessory exec web "./manage.py migrate"        -c config/deploy.glitchtip.yml
   bin/kamal accessory exec web "./manage.py createsuperuser" -c config/deploy.glitchtip.yml
   ```

3. In the GlitchTip UI (reach it via `ssh -L 8080:localhost:8080 <server>`):
   create an **Organization** and a **Project** → copy the **DSN**. Because the
   app and GlitchTip share the kamal docker network, use the internal host:
   `http://<key>@glitchtip-web:8080/<project_id>`.

4. Set `SENTRY_DSN` in the app deploy env and redeploy. Errors now flow in.

5. Create an **org auth token** (Settings → Auth Tokens) — this is what the
   error-triage routine uses to read issues via the API in GlitchTip mode. Store
   it as `GLITCHTIP_API_TOKEN`.

---

## 3. The self-healing loop — error-triage routine + pr-watcher

```
production errors ──▶  error-triage routine  (local /loop or cloud routine)
   (raw logs OR              │  triage → dedup → spawn fix sub-agent
    GlitchTip issues)        │  open PR (label: from:watcher)
                             ▼
                        RemoteTrigger: run pr-watcher
                             │
                   PR-WATCHER reviews + merges green PRs
                             │
                     CI → deploy.yml → Kamal → production
```

Two **separate authorities**, on purpose:

- The **error-triage routine** *investigates and proposes*. It reads the error
  signal (raw logs and/or GlitchTip), decides what is a real code bug, writes a
  fix + regression test on a branch, and opens a PR. It **never merges**. (Name
  it whatever — it's just a routine.)
- **pr-watcher** *remains the single merge gatekeeper* (existing routine, all its
  guardrails intact). The triage routine just **triggers a run** so the fix is
  reviewed in seconds instead of waiting for the hourly cron — via the
  remote-trigger run endpoint (`POST /v1/code/triggers/{pr-watcher_id}/run`).

The signal source (logs vs GlitchTip) and runtime (local `/loop` vs cloud
routine) are independent choices — see the table in
[`docs/agents/error-triage-routine.md`](../agents/error-triage-routine.md), the
full operating contract.

### Guardrails (why this is safe to run unattended)

- **PR-only, never push to `main`.** Merge stays gated by CI + pr-watcher.
- **Signature/fingerprint dedup state** — the routine records which errors it has
  already actioned (an open `from:watcher` PR, or a resolve/annotate on the
  GlitchTip issue) so it never opens duplicate PRs or re-opens handled ones.
- **Rate limit / circuit breaker** — cap PRs per run. A bad deploy that spikes
  errors must not trigger a storm of agent PRs.
- **Triage filter** — only high-confidence *code* bugs get a PR. Transient
  network / bad-bot-input / user error is annotated, not patched.
- **Regression guard** — if errors spike right after a deploy, the right move is
  `kamal rollback`, **not** a forward-fix PR. The routine flags this for a human
  instead of trying to out-code a bad release.
- **Privacy** — the routine summarizes error evidence; it never pastes raw request
  data, PII, or `.private/` content into a PR or issue (same rule as
  `docs/agents/issue-tracker.md`).

---

## 4. Rollout order

The fastest start needs **none** of the GlitchTip bring-up — a local `/loop`
watching `bin/prod-logs` can drive the whole loop today. GlitchTip is the upgrade
that makes it always-on.

1. ✅ **App instrumentation** — SDK + scrubber + DSN-gated initializer (this PR).
   Harmless until a DSN is set; useful immediately once GlitchTip exists.
2. **Prove the loop cheaply** — a local `/loop` error-triage routine over raw
   logs (`bin/prod-logs --once --grep …`), **PR-only with a human merge**, for a
   few cycles to watch its judgment.
3. **Boot GlitchTip** (for always-on) — §2 above; set `SENTRY_DSN`; confirm a test
   exception appears (`Sentry.capture_message("hello")` from a prod console).
4. **Move to a cloud routine over GlitchTip** and **close the loop** — enable the
   `RemoteTrigger` pr-watcher kick once the routine's PR quality is trusted
   (mirrors how pr-watcher itself was rolled out).
