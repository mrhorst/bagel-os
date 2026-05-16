# Domain Docs

This repo uses a single-context domain layout.

## Layout

- Root context: `CONTEXT.md`
- Architecture decisions: `docs/adr/`
- Agent setup docs: `docs/agents/`

## Agent Rules

- Read `CONTEXT.md` before architecture, diagnosis, TDD planning, or broad refactor work.
- Read relevant ADRs under `docs/adr/` before changing an established architectural decision.
- If domain details are install-specific or private, keep them in `.private/notes/` and summarize only the non-sensitive rule in tracked docs.
- Do not treat private restaurant operating data as generic product truth.
