# [MEDIUM] No `permissions:` block: GITHUB_TOKEN inherits repo default and is persisted to disk by checkout

**File:** [`.github/workflows/ci.yml`](https://github.com/daniace/doro-omarchy/blob/main/.github/workflows/ci.yml#L8-L13) (lines 8, 9, 13)
**Project:** doro-omarchy
**Severity:** MEDIUM  •  **Confidence:** medium  •  **Slug:** `other-overprivileged-ci-token`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

The workflow declares no `permissions:` key at either workflow or job level (verified: no `permissions`, `concurrency`, or `persist-credentials` key exists anywhere in the file). `GITHUB_TOKEN` therefore inherits the repository/organization default scope. If this repo uses the legacy 'Read and write permissions' default, every run — including the `push: branches: [main]` trigger on L5-6 — receives a token with `contents: write`.

This is compounded by `actions/checkout@v4` (L13), which defaults to `persist-credentials: true` and writes that token into `.git/config` as an `http.extraheader`. The credential then sits on disk for the remainder of the job, readable by every subsequent step — including the `node tests/*.test.mjs` steps (L28-30) that execute JavaScript from the repository tree.

On `pull_request` runs from a fork the token is read-only, so exposure is bounded there. The real risk is on `push` to `main`, where a write-scoped token is materialized on disk next to arbitrary code execution from any compromised step or action (see the unpinned-action finding). Because this repository is distributed as an Omarchy marketplace plugin (`manifest.json` id `doro.pomodoro`) that loads directly into the long-lived `omarchy-shell` process on end users' desktops, write access to the repo is a supply-chain foothold on user machines, not just a CI inconvenience.

The job needs nothing beyond reading source: it only runs `jq`, `find`, and three Node test scripts.

## Recommendation

Add a least-privilege block at workflow level: `permissions:\n  contents: read`. Additionally set `with:\n  persist-credentials: false` on the `actions/checkout` step, since no step in this job uses git credentials after checkout.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
