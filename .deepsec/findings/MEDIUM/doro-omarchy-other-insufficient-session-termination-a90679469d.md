# [MEDIUM] Sign-out never revokes the session server-side

**File:** [`Nube.qml`](https://github.com/daniace/doro-omarchy/blob/main/Nube.qml#L207-L209) (lines 207, 208, 209)
**Project:** doro-omarchy
**Severity:** MEDIUM  •  **Confidence:** high  •  **Slug:** `other-insufficient-session-termination`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

`salir()` is just `establecerSesion(null)` (L207-209): it overwrites sesion.json with `null` and drops the in-memory copy, but never calls `POST /auth/v1/logout`. The refresh token remains valid at Supabase until it is rotated or expires, so any copy that leaked earlier — via process argv (see above), a backup, a synced dotfile directory, or the pre-chmod window — still mints fresh access tokens long after the user believes they signed out. `tokenAnonimoPorFusionar` is likewise not cleared by `salir()`, so a stale anonymous bearer token is retained in memory and will be POSTed to `sumar-anonimo` on the *next* successful sign-in, attaching the previous identity's data to whichever account signs in next.

## Recommendation

In `salir()`, fire `pedirConSesion("POST", "/auth/v1/logout", {}, null, false, ...)` (scope `global` if all devices should be cut) before clearing local state, clear `tokenAnonimoPorFusionar` and `proveedorEnCurso`, and clear local state unconditionally even if the request fails.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
