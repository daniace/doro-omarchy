# [MEDIUM] Server-supplied URL handed to xdg-open with no scheme allow-list

**File:** [`Nube.qml`](https://github.com/daniace/doro-omarchy/blob/main/Nube.qml#L156-L275) (lines 156, 274, 275)
**Project:** doro-omarchy
**Severity:** MEDIUM  •  **Confidence:** medium  •  **Slug:** `unsafe-redirect`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

In `entrar()`, the linkIdentity response body is dereferenced and opened directly: `if (estado === 200 && datos && datos.url) abrir(datos.url)` (L156), where `abrir` is `Quickshell.execDetached(["xdg-open", url])` (L274-276). `datos.url` is an arbitrary JSON string from `/auth/v1/user/identities/authorize`; nothing constrains it to `https://`. `xdg-open` dispatches on scheme/MIME, so a value such as `file:///home/<user>/Downloads/payload.desktop`, or any scheme with a registered handler, launches that handler instead of a browser. The precondition is control of the response — a compromised or repointed backend (`conf.url` is overridable via the plugin `.env` or `~/.config/doro/supabase.json`) — so this is a trust-boundary hardening gap rather than a directly attacker-reachable path, but it converts a backend compromise into local code execution. `abrirDashboard` is safe by comparison (constant `Supabase.URL_WEB`).

## Recommendation

Validate before spawning: in `abrir(url)`, require `/^https:\/\//.test(url)` (and optionally that the host matches the configured Supabase host or doro.page) and drop anything else with a `console.warn`. Apply the same guard to any future caller.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
