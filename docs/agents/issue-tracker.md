# Issue Tracker

This repository uses GitHub Issues.

## Repository

- Host: GitHub
- Expected repository: `mrhorst/bagel-os`
- Visibility: private

## How Agents Should Work

- Read issues from GitHub Issues.
- Create issues with the GitHub connector or `gh issue create` once the remote exists.
- Use issue comments for clarifying questions, investigation notes, and implementation handoff.
- Do not create local `.scratch/` issue files unless GitHub is unavailable and the user explicitly approves a temporary local workflow.

## Private Data Rule

Never paste real receipt rows, private order guide PDFs, vendor account identifiers, staff/customer data, or `.private/` content into GitHub issues. Summarize sensitive evidence and point to the local private path when needed.
