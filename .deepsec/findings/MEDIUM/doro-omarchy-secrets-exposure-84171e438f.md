# [MEDIUM] Session access and refresh tokens passed through process argv

**File:** [`Nube.qml`](https://github.com/daniace/doro-omarchy/blob/main/Nube.qml#L296-L300) (lines 296, 299, 300)
**Project:** doro-omarchy
**Severity:** MEDIUM  •  **Confidence:** high  •  **Slug:** `secrets-exposure`

## Owners

**Suggested assignee:** `daniel.emiliano.acevedo@gmail.com` _(via last-committer)_

## Finding

The generated handler is `Exec=omarchy-shell doro.pomodoro authCallback %u` (L296-300). Because the plugin uses the OAuth *implicit* flow, `%u` is the full callback URL including `access_token` and `refresh_token`. Those bearer credentials therefore land in the command line of the `omarchy-shell` invocation (and of the intermediate `xdg-open`/`gio` chain). `/proc` on this host is mounted without `hidepid` (verified: `rw,nosuid,nodev,noexec,relatime`), so `/proc/<pid>/cmdline` is readable by every local account — any other user, or any unprivileged process, can scrape a complete Supabase session with a `ps`/`/proc` poll loop. Supabase refresh tokens are long-lived until rotated, so a single capture yields durable access to the account. This directly violates the project's own stated rule that tokens must never reach `execDetached` argv. Severity is held at MEDIUM because it requires a second local account or a co-tenant process to be watching during the window.

## Recommendation

Adopting PKCE (see the finding above) fixes this too: the callback URL then carries only a single-use authorization code that is useless without the locally-held verifier. If the implicit flow must stay, have the .desktop entry write the URL to a 0600 file in `$XDG_RUNTIME_DIR` (or pipe it over a user-only socket) and pass only that path over IPC, so no credential appears in argv.

## Recent committers (`git log`)

- Daniel Emiliano Acevedo <daniel.emiliano.acevedo@gmail.com> (2026-10-27)
