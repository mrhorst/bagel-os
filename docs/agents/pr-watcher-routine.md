# PR watcher routine

A scheduled Claude routine that moves every open PR in `mrhorst/bagel-os` to a
terminal state each run. It separates review readiness from merge execution:
required human review is a handoff point, not an error to retry.

## States

Every run leaves each open PR in exactly one state:

1. **Merged / auto-merge armed** — approved, green, mergeable, labelled for merge.
2. **Ready for human review** — green and mergeable; the only blocker is required
   review. Review packet posted.
3. **Agent working** — CI failure, stale branch, or conflict the watcher is fixing.
4. **Blocked** — needs a human. Only for the blockers listed below.

Never silently spin. If a PR can't move, the sticky comment says why.

## Blockers (the only three)

Escalate to a human **only** when:

1. **Required review** on a PR that doesn't qualify for `safe-automerge` —
   post the packet, label, stop. Don't retry merge with no new information.
2. **High-risk diff** — migrations/schema, deploy/CI/secrets/env, auth/sessions/
   owner logic, payment/customer/staff/private data, importers over real data,
   or large broad rewrites. When uncertain, treat as high-risk.
3. **CI failure needing something the agent doesn't have** — an external
   secret, service, or credential decision.

Everything else is agent work, not a blocker. Fix it:

- **Failed checks** → read `gh run view --log-failed`, commit the minimal fix on
  the PR branch, push.
- **Stale branch** → update it (`gh pr update-branch` or merge main into it).
- **Conflicts** → resolve them on the PR branch. Escalate only if resolution
  touches a high-risk path or the intent of both sides is genuinely ambiguous.
- **Missing labels** → create them.
- **Pending checks** → skip this run; no comment, no waiting.
- **Draft PRs** → skip.

## Labels

| Label | Meaning |
| --- | --- |
| `automerge` | Merge automatically once policy allows. |
| `safe-automerge` | Low-risk; eligible for the trusted reviewer-bot path if enabled. |
| `agent-reviewed` | Watcher posted its current review packet. |
| `needs-human-review` | Do not auto-approve or auto-merge. |
| `blocked` | Cannot progress without external input. |
| `from:watcher` | Produced by an agent watcher loop. |

`safe-automerge` is only for docs, tests, copy, and small CSS/UI tweaks — never
migrations, deploy/auth/secrets, billing, destructive data changes, or
private-data-touching code.

## Sticky comment

Maintain exactly one comment per PR containing `<!-- pr-watcher state -->`;
update it, never add a second one.

```md
<!-- pr-watcher state -->
## PR watcher status

State: Ready for review / Auto-merge armed / Agent working / Blocked
Risk: Low / Medium / High
Suggested action: Approve + auto-merge / Review manually / None (watcher fixing)

Why:
- CI / Review / Mergeability: one line each
- Diff focus: 2-4 bullets naming the important files/areas
- Security/privacy, tests, deploy/data risk: pass or one-line concern each
```

Never paste private data, `.private/` content, raw receipt rows, account IDs,
or customer/staff details into comments.

## Merging

When checks are green, review approved, branch mergeable, and the PR has
`automerge` or `safe-automerge`:

```sh
gh pr merge PR_NUMBER --auto --squash --delete-branch
```

## Scheduled prompt

```text
You are the Bagel OS PR watcher for mrhorst/bagel-os. Move every open non-draft
PR to a terminal state: merged/auto-merge armed, ready for human review, agent
working, or blocked.

Hard rules:
- Never push to main or weaken branch protection.
- Never approve or merge a high-risk PR (migrations, deploy/CI/secrets, auth,
  payments/private data, importers, broad rewrites) autonomously.
- Never paste private data or .private content into comments.
- Maintain exactly one sticky comment per PR marked <!-- pr-watcher state -->.

Per PR:
1. Checks pending → skip. Draft → skip.
2. Checks failed → fix on the PR branch and push, unless the failure needs an
   external secret/service — then label blocked and say why in the comment.
3. Branch behind or conflicting → update/resolve on the PR branch.
4. Classify risk from the diff; when uncertain, high.
5. Green + approved + mergeable + automerge/safe-automerge label →
   gh pr merge <n> --auto --squash --delete-branch.
6. Green but review required → update sticky comment with state, risk, and
   suggested action; add agent-reviewed; add needs-human-review unless it
   qualifies as safe-automerge. Do not retry merge.

Finish with a compact table: PR, state, risk, action taken.
```

## Optional trusted reviewer-bot path

GitHub required reviews must come from a non-author identity. If autonomous
approval is wanted, use a separate bot account with write access, restricted to:
`safe-automerge` label + green CI + low-risk diff + watcher comment already
posted, and never for high-risk paths (`.github/workflows/**`, `.kamal/**`,
`config/deploy*.yml`, `config/credentials/**`, `db/migrate/**`, `db/schema.rb`,
auth controllers/models, `app/services/**/import*`, web-push/Sentry
initializers).

The safer default remains: watcher prepares the packet, a human approves,
GitHub auto-merge finishes. Keep required reviews enabled either way.
