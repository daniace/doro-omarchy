# [BUG] Identity change leaves stale room membership and silently breaks room sync

**File:** [`Sala.qml`](https://github.com/daniace/doro-omarchy/blob/main/Sala.qml#L116-L123) (lines 116, 118, 120, 121, 122, 123)
**Project:** doro-omarchy
**Severity:** BUG  •  **Confidence:** medium  •  **Slug:** `other-logic-bug`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

The `Connections` block on `nube` reacts to `onSesionChanged` only by pushing the new `access_token` to the open websocket (L120-123); it never re-runs `conectar()`. But room membership is per-user (`join_room_by_id`, L100), so after the identity changes, `unida` stays true for a user who is no longer a member. This is reachable through normal use: `signOut` (`nube.salir()`) does not call `sala.salir()`, and if any pomodoros are pending, `subirPendientes` immediately creates a *new anonymous user* via `asegurarSesion(true, ...)`. From then on `update_room_sync` (L153) is rejected under RLS for every local change — logged only as a `console.warn` at L156 — and `traerEstado` (L167) sees an empty result set, so inbound updates stop as well. The panel and `status()` still report `joined: true` with a live room code, so the timer silently stops being shared with no user-visible error until the shell restarts and `conectar()` re-joins as the new identity.

## Recommendation

Make the room follow the identity: in the `onSesionChanged` handler, if the user id differs from the one the room was joined with, reset `unida = false` and call `conectar()` to re-run `join_room_by_id` under the new identity (keeping `salaId`/`codigo` so the rejoin is transparent). Also have `Nube.salir()` notify the room, and surface a repeated `update_room_sync` rejection to the user instead of only `console.warn`.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
