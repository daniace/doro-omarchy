# [BUG] Unanchored version regex accepts non-semver manifest versions

**File:** [`.github/workflows/ci.yml`](https://github.com/daniace/doro-omarchy/blob/main/.github/workflows/ci.yml#L22) (lines 22)
**Project:** doro-omarchy
**Severity:** BUG  •  **Confidence:** high  •  **Slug:** `other-logic-bug`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

The manifest gate on L22 validates the version with `test("^[0-9]+\\.[0-9]+\\.[0-9]+")`, which has a start anchor but no `$` terminator. Any trailing content passes. I confirmed this by feeding a modified manifest through the same `jq` expression: a version of `0.1.0-$(id>/tmp/x)` returns `true`.

There is no injection consequence inside this workflow — `.version` is never interpolated into a shell command, so the garbage value is only ever compared, not executed. The practical impact is that the single automated guard on manifest well-formedness is weaker than it reads: a malformed version passes CI green and is then rejected later by stricter downstream validation (`omarchy plugin validate`, run by `scripts/instalar-local.sh`, and the marketplace submission checks), moving the failure to the least convenient point in the release flow.

## Recommendation

Anchor the pattern at both ends, allowing an explicit prerelease/build suffix only if intended: `test("^[0-9]+\\.[0-9]+\\.[0-9]+$")`.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
