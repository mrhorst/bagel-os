# PR watcher routine

A scheduled Claude routine for keeping Bagel OS pull requests moving without
turning branch protection into theater.

The old loop was too blunt: it asked GitHub "can this PR merge?" every hour,
then got stuck forever when the only blocker was `REVIEW_REQUIRED`. This routine
separates review readiness from merge execution.

## Goal

Every run should leave each open PR in one of these clear states:

1. **Merged or auto-merge armed** — already approved, checks green, mergeable.
2. **Ready for Mat** — checks green, blocked only by required review, with a
   compact review packet posted.
3. **Needs agent work** — CI failed, branch stale, or conflicts are fixable.
4. **Needs human judgment** — deploy/auth/data/privacy/high-risk changes or
   ambiguous failures.

Never silently spin on a PR. If the routine cannot move it, it should say why in
a durable PR comment.

## Labels

Use these labels as routine state. Create them if missing.

| Label | Meaning |
| --- | --- |
| `automerge` | Mat wants this PR merged automatically once policy allows it. |
| `safe-automerge` | Low-risk PR that may be auto-approved by a trusted reviewer bot if that path is enabled. |
| `agent-reviewed` | The watcher posted its current review packet. |
| `needs-human-review` | Do not auto-approve or auto-merge; Mat needs to look. |
| `blocked` | The routine cannot make progress without external input. |
| `from:watcher` | PR/comment was produced by an agent watcher loop. |

Keep `safe-automerge` narrow. It is for small docs, tests, copy, obvious CSS, or
low-risk UI tweaks. It is not for migrations, deploy/auth/secrets, production
infra, billing/payments, destructive data changes, or private-data-touching code.

## Hourly runbook

Run from the repo root with an authenticated `gh` CLI.

### 1. Refresh local state

```sh
git fetch --prune origin
git checkout main
git pull --ff-only origin main
```

If local `main` is dirty, stop and report `blocked`; do not merge or checkout PRs.

### 2. List open PRs

```sh
gh pr list --state open --limit 50 \
  --json number,title,author,isDraft,labels,mergeStateStatus,reviewDecision,statusCheckRollup,headRefName,baseRefName,url
```

Skip draft PRs except to comment if they have been stale for several days.

### 3. Classify status checks

For each non-draft PR:

- **Checks pending**: comment only if they have been pending unusually long.
- **Checks failed**: inspect logs with `gh run view --log-failed`; either fix in a
  branch commit or post the minimal failure summary. Label `blocked` only when it
  needs a human or external secret/service.
- **Checks green**: continue.

### 4. Classify risk

Use the diff, file paths, and PR body. Conservative defaults:

**Low risk / `safe-automerge` candidate**

- docs-only changes
- tests-only changes
- copy text or static view markup with no behavior change
- small CSS/layout fix
- isolated non-destructive helper refactor with tests

**Human review required**

- migrations or schema changes
- deploy/Kamal/GitHub Actions/secrets/env changes
- auth, authorization, sessions, owner/admin logic
- payment/billing/customer/staff/private data handling
- importers touching real vendor/POS/accounting data
- broad rewrites, generated code, or large diffs
- anything that changes production observability, notification delivery, or web push behavior

When uncertain, choose human review.

### 5. Produce/update one watcher comment

Maintain exactly one sticky comment per PR containing this marker:

```html
<!-- pr-watcher state -->
```

Update that comment instead of spamming new comments.

Comment format:

```md
<!-- pr-watcher state -->
## PR watcher status

State: Ready for Mat / Auto-merge armed / Needs agent work / Needs human judgment
Risk: Low / Medium / High
Suggested action: Approve + auto-merge / Review manually / Let watcher fix CI

Why:
- CI: green / pending / failed
- Review: approved / review required / changes requested
- Mergeability: clean / behind / conflicts / blocked
- Diff focus: 2-4 bullets naming the important files/areas

Watcher notes:
- Security/privacy: pass / concern + reason
- Tests: present / missing + reason
- Deployment/data risk: none / concern + reason
```

Do not paste private data, `.private/` content, raw receipt rows, account IDs, or
live customer/staff details into comments.

### 6. Merge or arm auto-merge when policy allows

If checks are green, review is approved, the branch is mergeable, and the PR has
`automerge` or `safe-automerge`:

```sh
gh pr merge PR_NUMBER --auto --squash --delete-branch
```

If GitHub says the PR can merge immediately, this command will merge it. If a
required check is still settling, it arms GitHub auto-merge.

### 7. Handle the required-review blocker intentionally

If the only blocker is required review:

- Post/update the watcher comment.
- Add `agent-reviewed`.
- Add `needs-human-review` unless the PR qualifies for `safe-automerge` and the
  trusted reviewer-bot approval path is enabled.
- Do **not** keep retrying merge every hour with no new information.

## Optional trusted reviewer-bot path

GitHub required reviews must come from an identity other than the PR author. If
all PRs are authored by Mat's account, the watcher cannot satisfy branch
protection as Mat.

If autonomous approval is desired, use a separate GitHub App or bot account with
write access, and restrict it hard:

- only approve PRs labelled `safe-automerge`
- only approve after CI is green
- only approve low-risk diffs by the rules above
- never approve PRs touching high-risk paths
- always post the watcher comment before approving

High-risk path denylist for bot approval:

```text
.github/workflows/**
.kamal/**
config/deploy*.yml
config/credentials/**
config/initializers/sentry.rb
config/initializers/web_push.rb
db/migrate/**
db/schema.rb
app/controllers/sessions_controller.rb
app/controllers/passwords_controller.rb
app/controllers/accounts_controller.rb
app/models/user.rb
app/models/account.rb
app/services/**/import*
app/services/**/web_push*
```

This bot path is optional. The safer default is: Claude prepares the review
packet, Mat approves, GitHub auto-merge handles the rest.

## Prompt for the scheduled Claude routine

Use this as the self-contained hourly prompt:

```text
You are the Bagel OS PR watcher for the GitHub repo mrhorst/bagel-os.
Run from /Users/agentlab/dev/work/restaurant-inventory-os.

Your job is not to blindly retry merges. Your job is to move every open PR to a
clear state: merged/auto-merge armed, ready for Mat, needs agent work, or needs
human judgment.

Hard rules:
- Preserve branch protection. Do not push to main. Do not remove required reviews.
- Never approve or merge high-risk PRs autonomously.
- Never paste private data, .private content, real vendor/account/staff/customer
  details, or raw operational exports into GitHub comments.
- Keep exactly one sticky PR comment marked: <!-- pr-watcher state -->.
- Prefer squash merge with branch deletion when merging/arming auto-merge.
- If blocked only by REVIEW_REQUIRED, post/update the review packet and stop;
  do not keep retrying merge.

Steps:
1. git fetch --prune origin; checkout main; pull --ff-only origin main. If local
   state is dirty, stop and report blocked.
2. List open PRs with gh, including checks, labels, reviewDecision, and
   mergeStateStatus.
3. For each non-draft PR:
   - summarize CI state
   - inspect the diff enough to classify risk
   - classify as low, medium, or high risk
   - identify whether the only blocker is required review
4. If checks failed and the failure is clearly fixable, make a minimal fix on the
   PR branch, commit, and push. Otherwise update the watcher comment with the
   failure summary.
5. If checks are green + approved + mergeable + labelled automerge or
   safe-automerge, run: gh pr merge <number> --auto --squash --delete-branch.
6. If checks are green but review is required, update the sticky watcher comment
   with State, Risk, Suggested action, Why, and Watcher notes. Add
   agent-reviewed. Add needs-human-review unless it qualifies as safe-automerge.
7. Final response: compact table of PR number, title, state, risk, action taken.
```

## Current recommended branch-protection posture

Keep required reviews enabled. The review requirement is doing useful work; the
broken part was the watcher treating it like an error instead of a handoff point.

If the routine proves reliable, consider enabling the separate reviewer-bot path
only for `safe-automerge`. Do not make the writer and merger the same authority.
