# [BUG] Overlapping sign-in attempts drop the handler-install callback

**File:** [`Nube.qml`](https://github.com/daniace/doro-omarchy/blob/main/Nube.qml#L289-L305) (lines 289, 291, 301, 303, 305)
**Project:** doro-omarchy
**Severity:** BUG  •  **Confidence:** medium  •  **Slug:** `other-logic-bug`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

`instalarManejador(cb)` stores the callback in the single-slot `alInstalarManejador` and sets `manejador.running = true` (L289-292). Two `signIn` calls in quick succession (two clicks on the provider buttons, or a scripted keybinding) overwrite the slot, and setting `running = true` on an already-running Process is a no-op, so `onExited` fires once and only the second callback runs (L301-306). The first sign-in attempt then silently does nothing — no browser opens and no error is shown. `proveedorEnCurso` has also already been overwritten by the second call at L148, so the completed flow can be attributed to the wrong provider in the `identity_already_exists` merge branch.

## Recommendation

Queue the callbacks in an array and drain all of them in `onExited`, or make `entrar()` a no-op (with user feedback) while `manejador.running` is true. Setting `alInstalarManejador = null` before invoking the callback is already correct; the fix is only the single-slot overwrite.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
