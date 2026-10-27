# [MEDIUM] Actions pinned to mutable major-version tags instead of commit SHAs

**File:** [`.github/workflows/ci.yml`](https://github.com/daniace/doro-omarchy/blob/main/.github/workflows/ci.yml#L13-L16) (lines 13, 16)
**Project:** doro-omarchy
**Severity:** MEDIUM  •  **Confidence:** medium  •  **Slug:** `other-unpinned-action`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

`actions/checkout@v4` (L13) and `actions/setup-node@v4` (L16) are referenced by mutable major-version tags. A tag is a movable pointer: if it is repointed to malicious code, every subsequent run of this workflow executes that code inside the job, before and alongside the repository's own steps.

Likelihood is low and I want to be explicit about that — both actions are GitHub-owned, from a verified creator, so this is defense-in-depth rather than an active exposure. It is nonetheless the pattern GitHub's own hardening guidance and OpenSSF Scorecard both call out, precisely because verified-creator status does not make a tag immutable.

What makes it worth fixing here rather than ignoring is the blast radius created by the missing `permissions:` block: arbitrary code in this job runs with whatever the repository's default `GITHUB_TOKEN` scope is, and with that token already written into `.git/config` by checkout's default `persist-credentials: true`. On the `push: main` trigger that plausibly means repo write access to a plugin shipped through the Omarchy marketplace and loaded into `omarchy-shell` on user desktops. There are no secrets in this workflow, which is what keeps this MEDIUM rather than higher.

## Recommendation

Pin both actions to full-length commit SHAs with the readable tag retained as a trailing comment, e.g. `uses: actions/checkout@<40-char-sha> # v4.2.2`. Use Dependabot (`package-ecosystem: github-actions`) to keep the pins current.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
