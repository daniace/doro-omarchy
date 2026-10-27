# [BUG] Null `usuario` throws inside the upload callback and wedges the pomodoro queue for the session

**File:** [`Nube.qml`](https://github.com/daniace/doro-omarchy/blob/main/Nube.qml#L84-L259) (lines 84, 226, 233, 255, 259)
**Project:** doro-omarchy
**Severity:** BUG  •  **Confidence:** medium  •  **Slug:** `other-logic-bug`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

`subirPendientes` sets `subiendo = true` (L226) and only clears it inside the callbacks. If `sesion` is non-null but `sesion.usuario` is null, `Supabase.filasSesiones(lote, usuario.id)` (L233) throws a TypeError *before* `subiendo = false` is reached, so the flag stays true forever: the 5-minute retry timer (L350-356) and every later `registrarPomodoro` hit the `subiendo` early-return at L225 and do nothing for the rest of the shell session. No data is lost (pendientes.json is intact and recovers on restart), but nothing reaches the dashboard until the shell restarts. `cargarResumen` has the same unguarded dereference (L259: it checks `!sesion` but then reads `usuario.id`), and `pedirConSesion`'s 401 path dereferences `sesion.expires_at` (L84) which can be null if `signOut` lands while a request is in flight. `sesion.usuario === null` is reachable whenever a stored or refreshed session lacks a `user` object: `Supabase.sesionGuardada` returns `usuario: null` for a truncated or hand-edited sesion.json, and `sesionDesdeRespuesta` returns `usuario: null` whenever a `/token?grant_type=refresh_token` response omits `user` (self-hosted or future GoTrue).

## Recommendation

Treat a session without a user as unusable: have `asegurarSesion` force a refresh (or return false) when `sesion.usuario` is falsy, and guard `subirPendientes`/`cargarResumen` with `if (!usuario) return`. Reset `subiendo` from a `try/finally` (or set it false at the top of the callback) so an exception can never strand the flag, and null-check `sesion` before `sesion.expires_at = 0` in the 401 retry.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
