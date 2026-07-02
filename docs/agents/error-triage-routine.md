# Error-triage routine (self-healing loop)

A scheduled routine that watches production for errors and turns the real,
fixable ones into pull requests, then hands them to
[`pr-watcher`](pr-watcher-routine.md) to review and merge.

The routine **proposes**; `pr-watcher` **disposes**. One agent never both
writes a fix and merges it to production. (Avoid the name "Hermes" — that's
already this app's AI gateway service.)

## Runtime and signal

Two independent choices, both already decided:

- **Start local**: a `/loop` on the operator's machine reading raw logs via
  `bin/prod-logs --once --grep 'Error|Exception'`. Zero new infra.
- **Upgrade to cloud + GlitchTip** for always-on: query the GlitchTip issues
  API (structured, deduplicated, fingerprinted). Needs `GLITCHTIP_BASE_URL`,
  `GLITCHTIP_ORG`, `GLITCHTIP_PROJECT`, `GLITCHTIP_API_TOKEN` in env, plus the
  pr-watcher routine id for the handoff trigger. All install-specific values
  live in `.private/`, never in tracked files.

Everything after "pull signal" is identical in both modes.

## Each run

1. **Pull signal** — new error lines / GlitchTip issues since the last run.
2. **Dedup** — skip any signature already actioned (an open `from:watcher` PR
   for it, or a resolved/annotated GlitchTip issue). Idempotent on signature:
   re-running over the same state creates no duplicate PRs or comments.
3. **Triage** each fresh error into exactly one bucket:
   - **code-bug** — backtrace lands in our code and the routine can reproduce
     or clearly explain the defect → fix it. Ambiguity is not an automatic
     escalation: investigate first (read the backtrace's code path, attempt a
     reproduction test). Only escalate if that fails.
   - **noise** — transient network, bad-bot input, malformed request, expected
     validation → record and skip. No PR, no escalation.
   - **needs-human** — see blockers below.
4. **Fix (code-bug only)** — spawn a fix sub-agent: reproduce from the
   backtrace, minimal fix **plus a regression test**, open a PR. PR body:
   root cause, error/issue link, introducing release, fails-before /
   passes-after. Labels: `from:watcher` + `ready-for-agent`.
5. **Hand off** — trigger an immediate `pr-watcher` run
   (`RemoteTrigger action=run trigger_id=<pr-watcher id>`).
6. **Audit** — leave a `<!-- watcher state -->` comment trail and link the PR
   back to the source error.

## Blockers (the only three)

Flag `ready-for-human` and stop **only** for:

1. **Post-deploy regression spike** — error volume jumped right after the most
   recent deploy. Recommend `kamal rollback`; never forward-fix a bad release.
2. **Security- or data-sensitive errors** — auth, payments, private data, or a
   fix that would change data. A false PR here costs more than a missed one.
3. **Investigation failed** — after actually reading the code path and
   attempting reproduction, the root cause is still unclear.

Everything else is either a code-bug (fix it) or noise (skip it).

## Hard rules

- **Never push to or merge `main`.** The routine only opens PRs; merge
  authority is `pr-watcher`'s alone.
- **≤ 3 PRs per run.** Action the highest-impact issues; leave the rest.
- **Privacy.** Summarize evidence; never paste raw request bodies, PII,
  vendor/account identifiers, or `.private/` content anywhere. Same rule as
  [`issue-tracker.md`](issue-tracker.md).
- **Labels.** Use the five-label vocabulary in
  [`triage-labels.md`](triage-labels.md) plus `from:watcher` as the source
  label.

## Scheduled prompt

```text
You are the Bagel OS error-triage routine. Pull production errors since the
last run (bin/prod-logs or the GlitchTip issues API), dedup against
already-actioned signatures (open from:watcher PRs, resolved GlitchTip
issues), and triage each fresh error: code-bug, noise, or needs-human.

Hard rules:
- Never push to or merge main; only open PRs. pr-watcher merges.
- At most 3 PRs per run, highest impact first.
- Never paste raw request bodies, PII, account identifiers, or .private
  content anywhere.

Escalate (ready-for-human) only for: an error spike right after the latest
deploy (recommend kamal rollback), security/data-sensitive fixes, or a root
cause still unclear after reading the code path and attempting reproduction.
Everything else: fix it or skip it as noise.

For each code-bug: reproduce from the backtrace, write the minimal fix plus a
regression test, open a PR (root cause, error link, introducing release,
fails-before/passes-after; labels from:watcher + ready-for-agent), then
trigger an immediate pr-watcher run. Finish with a compact table: error,
bucket, action taken.
```

## Rollout

Same as `pr-watcher`: run PR-only with a human merging for a few cycles, then
enable the automatic `pr-watcher` handoff once its PRs are trusted.
