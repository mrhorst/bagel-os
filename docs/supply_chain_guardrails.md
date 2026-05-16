# Supply Chain Guardrails

## Current npm Risk

As of 2026-05-14, this Rails app has no npm dependency surface:

- no `package.json`
- no JavaScript lockfile
- no `node_modules`
- no npm/yarn/pnpm/bun install command in app scripts

That means the current Mini Shai-Hulud / TanStack-style npm install-time attack does not have a place to execute in this project.

## Why This Matters

The May 2026 TanStack incident showed that even projects using modern release protections can be hit if CI workflows restore poisoned cache contents and run package install/build scripts. The bad packages executed during install, harvested developer and CI credentials, and propagated through package publishing access.

For this app, the safest choice is to stay npm-free unless a clear business need appears.

## Enforced Rule

`bin/check-no-npm-surface` fails if it finds:

- `package.json`
- `package-lock.json`
- `npm-shrinkwrap.json`
- `yarn.lock`
- `pnpm-lock.yaml`
- `bun.lock`
- `bun.lockb`
- `.npmrc`
- `.yarnrc`
- `node_modules`
- `.yarn`
- `.pnpm-store`
- npm/yarn/pnpm/bun/npx commands in CI, Dockerfile, `bin/`, or `script/`

The check is wired into local CI and GitHub Actions.

## If JavaScript Tooling Is Ever Needed

Do not simply remove the guard. First make an explicit security decision and add controls:

- require a lockfile
- pin dependencies
- disable install lifecycle scripts where possible
- use minimum package age / delayed updates where the package manager supports it
- keep npm tokens out of developer machines and CI unless absolutely required
- use least-privilege CI permissions
- avoid `pull_request_target` workflows that check out and run fork code
- isolate build caches by trust boundary
- run dependency and malware scanning before deploy

If those controls are not worth the overhead, keep the app npm-free.
