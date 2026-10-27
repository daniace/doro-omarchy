# doro-omarchy

## What this codebase does
Doro is an Omarchy bar plugin (Quickshell / Qt Quick) that puts the doro.page
Pomodoro timer in the desktop bar. It has no backend of its own: it is a desktop
client that talks to doro.page's shared Supabase project over HTTPS and WebSocket,
and it runs inside the long-lived `omarchy-shell` process — no daemon, no root, no
installer. Production code is ~10 files at the repo root: QML views plus three
`.pragma library` JavaScript modules holding the pure logic.

- `Service.qml` — the one-per-shell-session singleton: timer state, ambient sound
  players, persisted state, notifications, and the `ShellIpc` command surface.
- `BarWidget.qml`, `Panel.qml`, `AnilloDoro.qml`, `SonidoSinCortes.qml` — views (one
  widget per monitor). The panel holds the only free-text field (room invite/code).
- `Nube.qml` — Supabase session lifecycle, the `XMLHttpRequest` client, the offline
  pomodoro queue, `doro://` scheme-handler installation, and state/config file IO.
- `Sala.qml` — shared-room membership plus the Phoenix/Realtime WebSocket channel,
  with a 2-second REST poll as fallback when `qt6-websockets` is absent.
- `Model.js`, `Supabase.js`, `Textos.js` — timer math, room-link and OAuth-callback
  parsing, saved-state sanitizing, i18n.

Identifiers and comments are Spanish; the wire contract (`timer_state` keys, mode
names, IPC command names) is English to match the web app. Server-side authorization
lives in the doro.page repo (Supabase RLS + RPCs), not here.

## Auth shape
Identity is a Supabase session (JWT access token + refresh token) held in `Nube.qml`
and persisted to `~/.local/state/doro/sesion.json`.

- `asegurarSesion(crear, cb)` is the single gate: it refreshes near expiry
  (`Supabase.sesionVencida`, 60 s margin) and only creates an anonymous user
  (`POST /auth/v1/signup`, empty body) when a write needs one — reached from
  `subirPendientes`, never from reads.
- `pedirConSesion` attaches `apikey: anonKey` and `Authorization: Bearer <session>`,
  and on a 401 forces one refresh-and-retry. A 4xx refresh clears the session; a
  network error (status 0) keeps it.
- Sign-in is browser OAuth implicit flow: `Supabase.urlEntrar` (or
  `Supabase.urlVincular` with `skip_http_redirect=true` to link an account onto an
  anonymous session) → `xdg-open` → return through the `doro://auth` handler →
  `Supabase.parsearRetorno` → `GET /auth/v1/user` → `establecerSesion`.
- Realtime joins carry the access token in the `phx_join` payload and are re-armed
  with an `access_token` event when the session rotates; the anon key also rides in
  the WebSocket query string.
- The IPC surface has no caller authentication: any process in the user's session can
  invoke every command. Its only defenses are allow-lists (`Model.esModo`,
  `Supabase.esProveedor`, `Textos.IDIOMAS`, `root.secciones`, `Model.esUuid`).

## Threat model
- **Hostile local process / malicious web page.** `authCallback <url>` is callable by
  anything that can reach `omarchy-shell`, and `doro://` URLs can be triggered by a
  web page. Planting attacker tokens, or forcing `signIn`/`joinRoom` into an
  attacker's room, is the highest-value attack here.
- **Token exfiltration at rest or in logs.** `sesion.json` and the in-memory
  `tokenAnonimoPorFusionar` are bearer credentials; the state directory is chmod 700
  only after `mkdir -p` returns. `status()`, `console.warn`, notification bodies and
  process argv are all places a token must never land.
- **Untrusted peers in a shared room.** Any room member's `timer_state` drives local
  mode, durations and anchors through `Model.esEstadoReloj` → `Model.aplicarRemoto`.
- **Server- or peer-controlled values reaching the shell.** `xdg-open`, `wl-copy`,
  `xdg-mime` and `omarchy-notification-send` are spawned with remote-influenced
  arguments.
- **Config override paths.** The plugin-local `.env` and `~/.config/doro/supabase.json`
  can repoint the Supabase URL, so a writable override redirects all tokens and data.
- Not in scope for this repo: RLS policy correctness, the `sumar-anonimo` edge
  function, and anything about the doro.page web bundle.

## Project-specific patterns to flag
- New or widened `ShellIpc` functions in `Service.qml` that accept a string and reach
  the network, the session, the filesystem or a subprocess without an allow-list
  check — this is a local privilege surface, not an internal API.
- Any relaxation of the OAuth callback contract: the strict `doro://auth` prefix test
  in `Supabase.parsearRetorno`, or accepting tokens without the `GET /auth/v1/user`
  confirmation before `establecerSesion`.
- Tokens crossing a boundary: added to `status()` JSON, to `console.warn`, to a
  notification title/body, to `execDetached` argv, or written outside the chmod-700
  state directory.
- Remote state widening: `Model.esEstadoReloj` / `Model.configuracionDe` bounds
  (`MAX_SEGUNDOS_VALIDOS`, `acotarMinutos`) being dropped, or a `timer_state` /
  `postgres_changes` field flowing into a file path, a URL or process arguments.
- Server-controlled navigation: `abrir(datos.url)` in `Nube.qml` opens a URL returned
  by the linkIdentity response, and `instalarManejador` writes a `.desktop` file via
  `sh -c`. Flag any interpolation added into that shell string or into `abrir`.

## Known false-positives
- The hardcoded `URL_PROYECTO` / `ANON_KEY` in `Supabase.js` is deliberate: it is the
  same public anon key the web bundle ships, documented as such in README. It is not
  a leaked secret; authorization is Supabase RLS.
- `Quickshell.execDetached([...])` and `Process { command: [...] }` pass argv arrays,
  so there is no shell interpolation. The one `sh -c` (handler install) is a constant
  string with no injected values.
- PostgREST filters built by concatenation (`user_id=eq.` + id, `id=eq.` + salaId) are
  not SQL injection: the values are UUIDs from Supabase or validated by
  `Model.esUuid` before a room is ever entered.
- Spanish identifiers read like false hits: `salir()` means leave-room / sign-out (not
  process exit), `pedir` is "request", `aviso` is "notification", `conf` is connection
  config, `nube` is "cloud".
- Tight timers are measured and documented, not busy-loop bugs: 200 ms clock tick,
  50 ms crossfade tick, two always-playing `MediaPlayer`s per ambient sound (gapless
  loop workaround), 2 s room poll, 25 s Phoenix heartbeat.
- There is no HTTP server, listener or agent/LLM tool surface in this repo, so
  "missing authz on handler" shaped findings do not map. `tests/`, `.agents/`,
  `.claude/`, `sounds/`, `screenshots/` are out of scope; `.env` was not read.
