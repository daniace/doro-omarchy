# [MEDIUM] Backend URL is not required to be https, so tokens can be sent in cleartext

**File:** [`Nube.qml`](https://github.com/daniace/doro-omarchy/blob/main/Nube.qml#L66-L68) (lines 66, 67, 68)
**Project:** doro-omarchy
**Severity:** MEDIUM  •  **Confidence:** low  •  **Slug:** `other-insecure-transport`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

`Supabase.configuracion` (Supabase.js:59-70) accepts any string for `url`, trimming only trailing slashes. That value is used raw as the request base (`xhr.open(metodo, conf.url + ruta)`, L66) with `Authorization: Bearer <session>` attached (L68), and is turned into the websocket URL by a blind `replace(/^http/, "ws")` (Sala.qml:233) with the access token in the `phx_join` payload. An `http://` value in the plugin `.env` or `~/.config/doro/supabase.json` therefore sends session tokens over an unencrypted channel (`ws://`) with no warning — a realistic footgun for the documented 'point at a local Supabase' workflow, where the override then silently persists. Writing those config files requires local write access, so this is a hardening gap rather than a remotely reachable bug; the missing validation is what turns a config mistake into credential disclosure on the wire.

## Recommendation

Validate the configured URL in `Supabase.configuracion`: accept `https://` unconditionally, accept `http://` only for loopback hosts, and otherwise fall back to the built-in constants with a `console.warn`. Derive the websocket URL from the validated scheme instead of a `replace(/^http/, "ws")` on an unchecked string.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
