# Doro for Omarchy

**English** · [Español](README.es.md)

The [doro.page](https://doro.page) Pomodoro timer as a bar plugin for
[Omarchy](https://omarchy.org): no browser needed.

<p>
  <img src="screenshots/en/panel-timer.png" width="280" alt="The Doro panel">
  <img src="screenshots/en/panel-sounds.png" width="280" alt="Ambient sounds">
  <img src="screenshots/en/panel-in-room.png" width="280" alt="A shared room">
</p>

- **In the bar:** the Doro ring, which fills up with the phase, and the time next to
  it while a phase is running.
  - Left click: opens the panel.
  - Right click: starts or pauses.
  - Middle click: skips to the next phase.
- **In the panel:** the phase (click it to skip to the next one; the arrow switches to
  the stopwatch), the big clock with its progress line, start/pause, reset, the
  **times** of each phase with automatic breaks, and **ambient sounds** with a volume
  per sound. `Enter` starts or pauses and `Esc` closes it.
- When a phase ends, the Doro alarm plays and a notification shows up.

It behaves like the web timer: after a pomodoro comes a short break, after a break
comes a pomodoro, and with «Start breaks automatically» the next phase starts on its
own. The settings, the phase, the paused time and the sound mix are saved in
`~/.local/state/doro/omarchy.json`. As on the web, a timer left running when the
session closed comes back paused.

More screenshots, in English and Spanish, are in [`screenshots/`](screenshots).

## Your pomodoros on the dashboard

Every finished pomodoro is saved to your doro.page account, just like on the web: a
row in `study_sessions` with the configured minutes (breaks and the stopwatch don't
count), and the dashboard adds it to your day and your streak.

- Without an account, the first finished pomodoro creates an anonymous session, as on
  the web.
- In the panel, **Sign in with** Google, GitHub or Discord opens the browser. It comes
  back through `doro://auth`: the first time, the plugin registers
  `~/.local/share/applications/doro-auth.desktop` for that scheme. If the session was
  anonymous, the account is linked to it and keeps what you did; if the account
  already existed, the anonymous work is added to it (`sumar-anonimo`).
- Offline, the pomodoro waits in `~/.local/state/doro/pendientes.json` with its real
  time and is uploaded later (when the shell starts or every 5 minutes).
- The panel shows today's minutes and your streak, and opens the web dashboard.

## Rooms

The people button in the panel opens the room section: paste an invite link
(`doro.page/invitacion/…`), its code or a room link (`doro.page/room/…`), or create a
new room (the invite link gets copied). In a room, the panel and bar timer is
everyone's, as on the web: anyone can start it, pause it or change its phase and
times, and each person adds their own pomodoros to the dashboard. The bar shows the
room icon, and when the session opens again the plugin rejoins the room it was in.

- With `qt6-websockets` installed, changes arrive instantly (Supabase Realtime).
  Without it, the plugin checks the room every 2 seconds:

  ```sh
  sudo pacman -S qt6-websockets   # then omarchy-restart-shell
  ```

- Ambient sounds stay personal; the plugin doesn't show who's in the room or its tasks.

## Language

The plugin speaks English and Spanish. By default it follows the system (Spanish if
`LANG` starts with `es`, English otherwise). To change it, use the **EN / ES** switch
at the bottom of the panel, or:

```sh
omarchy bar set doro.pomodoro language es   # en | es
```

## Install

```sh
omarchy plugin add https://github.com/daniace/doro-omarchy
```

From a terminal, Omarchy asks whether to enable it and where in the bar to put it
(left, center or right); next to the clock is preselected (the manifest's
`defaultSection`). With `--yes` it doesn't ask and uses that spot. To move it later:

```sh
omarchy bar move doro.pomodoro --section right   # left | centerBegin | center | centerEnd | tray | right
```

## Keybindings and scripts (IPC)

```sh
omarchy-shell doro.pomodoro toggle            # start / pause
omarchy-shell doro.pomodoro reset
omarchy-shell doro.pomodoro nextMode
omarchy-shell doro.pomodoro mode stopwatch    # pomodoro | shortBreak | longBreak | stopwatch
omarchy-shell doro.pomodoro volume rain 40    # 0 turns it off
omarchy-shell doro.pomodoro toggleAmbient     # pause / resume the sounds
omarchy-shell doro.pomodoro panel             # open / close the panel
omarchy-shell doro.pomodoro section sounds    # the panel open on timer | times | sounds | room
omarchy-shell doro.pomodoro status            # JSON with the phase, the time, the account and the room
omarchy-shell doro.pomodoro testNotification  # the end-of-pomodoro notification and alarm
omarchy-shell doro.pomodoro language es       # en | es
omarchy-shell doro.pomodoro signIn github     # google | github | discord
omarchy-shell doro.pomodoro signOut
omarchy-shell doro.pomodoro dashboard         # opens doro.page/dashboard
omarchy-shell doro.pomodoro joinRoom https://doro.page/invitacion/AB12CD34   # or the code
omarchy-shell doro.pomodoro createRoom        # and copies the invite link
omarchy-shell doro.pomodoro copyRoomLink
omarchy-shell doro.pomodoro leaveRoom
```

For example, in `~/.config/hypr/bindings.conf`:

```
bindd = SUPER ALT, P, Doro: start or pause, exec, omarchy-shell doro.pomodoro toggle
```

## What it uses

- It runs inside the `omarchy-shell` process, with no services of its own and no
  extra permissions.
- Sound through QtMultimedia (`qt6-multimedia`, ships with Omarchy).
- Notifications through `omarchy-notification-send`, with the Doro logo in the theme's
  color (`~/.local/state/doro/icono-aviso.svg`, rewritten when the theme changes).
- It writes to `~/.local/state/doro/` (mode 700: `sesion.json` holds the tokens) and,
  when signing in, the `doro://` `.desktop` file.
- It talks to doro.page's Supabase over HTTPS (`/auth/v1`, `/rest/v1`,
  `/functions/v1/sumar-anonimo`) and, in a room, over WebSocket (`/realtime/v1`). The
  project and the anon key are constants in `Supabase.js`: the key is public (the same
  one the web ships) and what protects the data are the RLS policies. To point at
  another project, such as a local Supabase, use the plugin's `.env`
  (`DORO_SUPABASE_URL`, `DORO_SUPABASE_ANON_KEY`; see `.env.example`,
  `scripts/instalar-local.sh` copies it) or `~/.config/doro/supabase.json`
  (`{ "url": "…", "anonKey": "…" }`), which overrides both. With no project set up,
  the plugin works offline and the panel hides the account section.

## Development

A separate repo from [Doro-Pomodoro](https://github.com/leonelcnr/Doro-Pomodoro) while
the plugin matures; it doesn't touch the web repo. The code is in Spanish, like the
web: the logic mirrors `src/store/timerStore.ts` and
`src/features/timer/hooks/useTimerActions.ts`, and the sounds are copies of
`public/sounds` and `src/assets/sounds` (if they change there, bring them over). The
visible texts live in `Textos.js`.

```sh
scripts/instalar-local.sh      # installs from this copy; the first time it asks where it goes in the bar
node tests/model.test.mjs      # timer and room logic tests
node tests/supabase.test.mjs   # session, queue and summary tests
node tests/textos.test.mjs     # every visible text exists in English and Spanish
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

The shell reloads the widget when files change, but the service (`keepLoaded`) and an
already open panel may keep the old version: `omarchy-restart-shell` reloads them.

| File | What it does |
|---|---|
| `Service.qml` | The timer (one per session), the sounds, saved state, the language and the IPC |
| `BarWidget.qml` | The bar view (one per monitor); passes the `language` setting to the service |
| `Panel.qml` | The panel; the sounds use the web's mixer layout |
| `AnilloDoro.qml` | The Doro logo drawn with the theme colors |
| `SonidoSinCortes.qml` | A gapless looping ambient sound (two offset players with a crossfade) |
| `Model.js` | The pure timer logic, the same as `timerStore`, and the shared-timer logic |
| `Nube.qml` | The doro.page session, the dashboard pomodoros (with an offline queue) and the summary |
| `Sala.qml` | Joining, creating and leaving rooms; `timer_state` over Realtime or polling every 2 s |
| `Supabase.js` | The pure session, OAuth callback, queue and summary logic |
| `Textos.js` | The visible texts in English and Spanish |

## To do

- Test against the real Supabase: linking an anonymous session to a new account, and
  token renewal with a room open for more than an hour.
- Before publishing: add a `preview.png` (a screenshot of the panel) at the root.

## License

[MIT](LICENSE), © 2026 Daniel Emiliano Acevedo and Leonel Jeremias Canario.
