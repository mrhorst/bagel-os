# Error-triage routine (self-healing loop)

A scheduled routine that watches production for errors and turns the real,
fixable ones into pull requests, then hands them to `pr-watcher` to review and
merge. See [`pr-watcher-routine.md`](pr-watcher-routine.md) for the merge-side
routine. This document is the orchestration half of the loop in
[`docs/deployment/observability.md`](../deployment/observability.md).

The routine **proposes**; `pr-watcher` **disposes**. Keeping investigation and
merge authority separate is deliberate — one agent never both writes a fix and
merges it to production. (The name is cosmetic — but avoid "Hermes", which is
already this app's AI gateway service.)

## Two things to choose: where it runs, and what it reads

These are independent, and they're the only real decisions.

### Where it runs

| Runtime | Reaches prod how | Pros / cons |
| --- | --- | --- |
| **Local `/loop`** | Already has the deploy SSH key + repo on your machine | **Zero new infra, works today.** Only runs while your machine is on. Cloud routines also have a 1-hour min cron; a local loop can poll tighter. |
| **Cloud routine** | Can't SSH to the box — signal must be pulled to it (see below) | Always-on, unattended (like `pr-watcher`). Requires an externally reachable signal. |

### What it reads (the signal)

| Signal | How the routine consumes it | Quality |
| --- | --- | --- |
| **Raw logs** | `bin/prod-logs --once --grep 'Error\|Exception' -n N` (i.e. `kamal app logs --since`) | Simplest, no new infra. Ephemeral, noisy, no dedup/fingerprint, can miss errors between runs. Fine for a **local-loop starting point.** |
| **GlitchTip** | Query the issues API with an org token | Structured, deduplicated, retained, fingerprinted, release-tagged. The **durable** trigger; needed for an always-on cloud routine. |

Recommended path: **start as a local `/loop` over raw logs** to prove the loop
cheaply, then **upgrade to a cloud routine over GlitchTip** for always-on. The
triage→PR→handoff steps below are identical either way — only the first step
("pull signal") changes.

## What it does each run

1. **Pull signal.** Either grep new error lines from `bin/prod-logs --since` the
   last run, or query GlitchTip for issues unresolved + new/regressed since the
   last run.
2. **Dedup.** Skip any error whose signature/fingerprint was already actioned.
   Keep state off to the side — an existing open PR labelled `from:watcher` for
   that signature, and/or a resolve/annotate on the GlitchTip issue. Idempotent
   on signature.
3. **Triage** each fresh error into exactly one bucket:
   - **code-bug** — a defect in our code with a clear backtrace into the app →
     fix it.
   - **noise** — transient network, bad-bot input, malformed request, expected
     validation → record and skip, no PR.
   - **needs-human** — ambiguous, data-shaped, security-sensitive, or a likely
     post-deploy regression → flag `ready-for-human`, summarize, stop.
4. **Fix (code-bug only).** Spawn a fix sub-agent that reproduces from the
   backtrace, writes the minimal fix **plus a regression test**, and opens a PR.
   PR body: root-cause summary, the error/issue link, the release that introduced
   it, and the fails-before / passes-after of the test. Label `from:watcher` +
   `ready-for-agent`.
5. **Hand off.** After opening PR(s), trigger an immediate `pr-watcher` run so the
   fix is reviewed without waiting for its hourly cron:
   `RemoteTrigger action=run trigger_id=<pr-watcher routine id>`.
6. **Audit.** Leave a `<!-- watcher state -->` comment trail (mirrors pr-watcher's
   convention) and link the PR back to the source error.

## Guardrails (hard rules)

- **Never push to or merge `main`.** The routine only opens PRs. Merge authority
  is `pr-watcher`'s alone.
- **Cap PRs per run** (e.g. ≤ 3). Action the highest-impact issues; leave the rest
  for the next run. Never open a swarm of PRs.
- **Regression guard.** If error volume spiked right after the most recent deploy,
  do **not** forward-fix. Flag `ready-for-human` with a `kamal rollback`
  recommendation and stop. A bad release is rolled back, not patched live.
- **High-confidence only.** When unsure it's a real code bug, bucket it
  `needs-human`. A false PR costs more than a missed one.
- **Privacy.** Summarize evidence; never paste raw request bodies, PII,
  vendor/account identifiers, or `.private/` content into a PR, comment, or issue.
  Same rule as [`docs/agents/issue-tracker.md`](issue-tracker.md).
- **Idempotent.** Re-running over the same state must not create duplicate PRs or
  comments.

## Triage labels

Use the standard five-label vocabulary from
[`docs/agents/triage-labels.md`](triage-labels.md). Apply `from:watcher` as a
separate source label so the routine's PRs are filterable and its dedup state is
queryable.

## Configuration (env, not tracked)

Log-watching (local loop) needs only the deploy SSH access you already have.
GlitchTip mode also needs:

| Var | Purpose |
| --- | --- |
| `GLITCHTIP_BASE_URL` | issues API base |
| `GLITCHTIP_ORG` / `GLITCHTIP_PROJECT` | which project's issues to read |
| `GLITCHTIP_API_TOKEN` | org auth token |
| pr-watcher routine id | target of the `RemoteTrigger` run that kicks the merge |

The real pr-watcher routine id and GlitchTip host are install-specific — keep
them in `.private/` / the operator's notes, not in tracked files.

## Rollout

Bring it up the way `pr-watcher` was: start **PR-only with a human merging** for a
few cycles to watch judgment quality, then enable the automatic `pr-watcher`
hand-off once its PRs are trusted.
