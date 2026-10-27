# [HIGH] OAuth callback accepts unsolicited tokens — session fixation via doro:// or IPC

**File:** [`Nube.qml`](https://github.com/daniace/doro-omarchy/blob/main/Nube.qml#L163-L192) (lines 163, 164, 167, 171, 178, 185, 191, 192)
**Project:** doro-omarchy
**Severity:** HIGH  •  **Confidence:** high  •  **Slug:** `auth-bypass`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

`recibirRetorno(url)` installs any session handed to it. `Supabase.parsearRetorno` (Supabase.js:113-127) only checks the literal prefix `doro://auth`, then merges query AND fragment params and returns whatever `access_token`/`refresh_token` it finds. There is no `state` nonce, no PKCE verifier, and no check that a sign-in is actually in progress (`proveedorEnCurso` is only consulted on the error path at L167, never on the token path). The `GET /auth/v1/user` call at L178 proves only that the token is a valid token for the configured project — not that it belongs to the local user — and on success `establecerSesion(tokens)` (L185) overwrites the real session and persists it to sesion.json.

Two attacker paths, both unauthenticated:
(1) Remote: a web page navigates to `doro://auth?access_token=<ATTACKER_JWT>&refresh_token=<ATTACKER_RT>&expires_in=3600`. I confirmed the handler is installed and is the registered system default (`~/.config/mimeapps.list`: `x-scheme-handler/doro=doro-auth.desktop`, `Exec=omarchy-shell doro.pomodoro authCallback %u`), so this reaches the plugin behind only the browser's generic external-protocol prompt, which does not display the payload. Note tokens are accepted in the query string, so no fragment handling is needed.
(2) Local: any process in the user's session calls `omarchy-shell doro.pomodoro authCallback '<url>'` directly (Service.qml:444) — no prompt at all.

Impact: the victim silently runs on the attacker's identity. `establecerSesion` is followed by `alCambiarSesion()` -> `subirPendientes()` (L192, L211-214), so the victim's queued offline pomodoros are immediately POSTed to `study_sessions` with `user_id` = the attacker's id (L233) — outbound data exfiltration, not just defacement. All future pomodoros, room creations and room joins also run under the attacker's account, and the panel shows the attacker's streak/stats as if signed in normally.

Escalation that steals the victim's own credential: the `identity_already_exists` branch (L167-171) copies the victim's anonymous access token into `tokenAnonimoPorFusionar`. `proveedorEnCurso` is never cleared on failure paths, so once the user has attempted one sign-in it stays armed. An attacker sends `doro://auth?error_code=identity_already_exists` (arming the merge), then `doro://auth#access_token=<attacker>` — `fusionarAnonimo` (L196-205) then POSTs the victim's bearer token to `/functions/v1/sumar-anonimo` authenticated as the attacker, merging the victim's anonymous study history into the attacker-controlled account.

## Recommendation

Switch to the PKCE flow: add `flow_type=pkce` + `code_challenge` in `Supabase.urlEntrar`/`urlVincular`, keep the verifier in memory only, and exchange the returned `code` via `POST /auth/v1/token?grant_type=pkce`. That cryptographically binds the callback to the locally-initiated flow. Until then, at minimum: (a) generate a random nonce per sign-in, pass it in `redirect_to` (`doro://auth/<nonce>`), and reject any callback whose nonce does not match the single in-flight value; (b) require `proveedorEnCurso !== ""` before accepting tokens and clear it on every terminal path including failures; (c) expire the in-flight flow after ~2 minutes and make it one-shot; (d) clear `tokenAnonimoPorFusionar` in `salir()` and on flow expiry; (e) make the prefix test exact (`doro://auth` followed by end, `/`, `?` or `#`) rather than `indexOf(...) === 0`.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
