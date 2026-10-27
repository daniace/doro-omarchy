# [BUG] Unquoted command substitution makes the entry-point existence check both bypassable and falsely failing

**File:** [`.github/workflows/ci.yml`](https://github.com/daniace/doro-omarchy/blob/main/.github/workflows/ci.yml#L23) (lines 23)
**Project:** doro-omarchy
**Severity:** BUG  •  **Confidence:** high  •  **Slug:** `other-logic-bug`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

L23 iterates `for f in $(jq -r '.entryPoints[]' manifest.json)`. The unquoted command substitution undergoes word splitting *and* pathname expansion, which breaks the check in two opposite directions. I verified both in a scratch directory:

1. **Glob values silently pass.** With `entryPoints` set to `{"service": "*.qml"}`, the `*.qml` is expanded by the shell against the working directory, every expanded name exists, and the loop exits 0 — so a manifest declaring an entry point that does not exist as a literal file is validated as present. The gate that is supposed to prove each declared entry point is on disk can be satisfied without that being true.

2. **Legitimate paths containing whitespace falsely fail.** With `{"service": "my widget.qml"}` and that exact file present, word splitting produces `my` and `widget.qml`; `test -f my` fails and `bash -e` aborts the step. A correct manifest fails CI with no useful diagnostic.

This is not a shell-injection issue: there is no `eval`, and the loop body quotes `"$f"` correctly, so values are only ever arguments to `test -f`. Note also that `.entryPoints` is a JSON *object* here, not an array; `jq -r '.entryPoints[]'` iterates object values, so it correctly yields `Service.qml` and `BarWidget.qml` — that part is fine.

## Recommendation

Iterate NUL-delimited values with globbing disabled, e.g. `set -f` before the loop, or preferably do the whole check inside a `while IFS= read -r f; do test -f "$f" || { echo "missing entry point: $f" >&2; exit 1; }; done < <(jq -r '.entryPoints[]' manifest.json)`. Emitting the offending path on failure also fixes the silent-diagnostic problem.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
