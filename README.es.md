# Doro para Omarchy

[English](README.md) · **Español**

El reloj Pomodoro de [doro.page](https://doro.page) como plugin de la barra de
[Omarchy](https://omarchy.org): sin abrir el navegador.

<p>
  <img src="screenshots/es/panel-timer.png" width="280" alt="El panel de Doro">
  <img src="screenshots/es/panel-sounds.png" width="280" alt="Los sonidos ambientales">
  <img src="screenshots/es/panel-in-room.png" width="280" alt="Una sala compartida">
</p>

- **En la barra:** el anillo de Doro, que se llena con la fase, y el tiempo al lado
  cuando hay una fase en curso.
  - Clic izquierdo: abre el panel.
  - Clic derecho: arranca o pausa.
  - Clic medio: pasa a la fase siguiente.
- **En el panel:** la fase (tocala para pasar a la siguiente; la flechita lleva al
  cronómetro), el reloj grande con su hilo, arrancar/pausar, reiniciar, los
  **tiempos** de cada fase con el descanso automático y los **sonidos ambientales**
  con un volumen por sonido. `Enter` arranca o pausa y `Esc` cierra.
- Al terminar una fase suena la alarma de Doro y llega una notificación.

Se comporta como el reloj de la web: al terminar un pomodoro pasa al descanso corto,
al terminar un descanso vuelve al pomodoro, y con «Arrancar el descanso solo» la fase
siguiente arranca sola. La configuración, la fase, el tiempo en pausa y la mezcla de
sonidos se guardan en `~/.local/state/doro/omarchy.json`. Como en la web, un reloj
que quedó corriendo al cerrar la sesión vuelve en pausa.

Hay más capturas, en inglés y en español, en [`screenshots/`](screenshots).

## Tus pomodoros en el dashboard

Cada pomodoro que termina se guarda en tu cuenta de doro.page, igual que en la web:
una fila en `study_sessions` con los minutos configurados (los descansos y el
cronómetro no cuentan), y el dashboard lo suma a tu día y a tu racha.

- Sin cuenta, el primer pomodoro terminado crea una sesión anónima, como en la web.
- En el panel, **Entrar con** Google, GitHub o Discord abre el navegador. La vuelta
  llega por `doro://auth`: la primera vez el plugin registra
  `~/.local/share/applications/doro-auth.desktop` para ese esquema. Si la sesión
  era anónima, la cuenta se le vincula y conserva lo hecho; si la cuenta ya existía,
  lo anónimo se le suma (`sumar-anonimo`).
- Sin conexión, el pomodoro queda en `~/.local/state/doro/pendientes.json` con su
  hora real y se sube después (al arrancar el shell o cada 5 minutos).
- El panel muestra lo de hoy y la racha, y abre el dashboard web.

## Salas

El botón de personas del panel abre la sala: pegá el link de una invitación
(`doro.page/invitacion/…`), su código o el link de la sala (`doro.page/room/…`), o
creá una sala nueva (el link de invitación queda copiado). En una sala, el reloj del
panel y de la barra es el de todos, como en la web: cualquiera lo arranca, lo pausa
o le cambia la fase y los tiempos, y cada uno suma sus propios pomodoros al
dashboard. La barra muestra el ícono de la sala, y al volver a abrir la sesión el
plugin vuelve a entrar a la sala en la que estaba.

- Con `qt6-websockets` instalado los cambios llegan al instante (Realtime de
  Supabase). Sin él, el plugin consulta la sala cada 2 segundos:

  ```sh
  sudo pacman -S qt6-websockets   # y después omarchy-restart-shell
  ```

- Los sonidos ambientales siguen siendo de cada uno; el plugin no muestra quién
  está en la sala ni sus tareas.

## Idioma

El plugin habla inglés y español. Por defecto sigue al sistema (español si `LANG`
empieza con `es`, inglés si no). Para cambiarlo, usá el selector **EN / ES** al pie
del panel, o:

```sh
omarchy bar set doro.pomodoro language es   # en | es
```

## Instalar

```sh
omarchy plugin add https://github.com/daniace/doro-omarchy
```

Desde una terminal, Omarchy pregunta si habilitarlo y en qué parte de la barra
ponerlo (izquierda, centro o derecha); viene marcado al lado del reloj
(`defaultSection` del manifest). Con `--yes` no pregunta y usa esa ubicación.
Para moverlo después:

```sh
omarchy bar move doro.pomodoro --section right   # left | centerBegin | center | centerEnd | tray | right
```

## Atajos y scripts (IPC)

Los comandos están en inglés, igual en los dos idiomas:

```sh
omarchy-shell doro.pomodoro toggle            # arrancar / pausar
omarchy-shell doro.pomodoro reset
omarchy-shell doro.pomodoro nextMode
omarchy-shell doro.pomodoro mode stopwatch    # pomodoro | shortBreak | longBreak | stopwatch
omarchy-shell doro.pomodoro volume rain 40    # 0 lo apaga
omarchy-shell doro.pomodoro toggleAmbient     # pausar / reanudar los sonidos
omarchy-shell doro.pomodoro panel             # abrir / cerrar el panel
omarchy-shell doro.pomodoro section sounds    # el panel abierto en timer | times | sounds | room
omarchy-shell doro.pomodoro status            # JSON con la fase, el tiempo, la cuenta y la sala
omarchy-shell doro.pomodoro testNotification  # el aviso y la alarma de fin de pomodoro
omarchy-shell doro.pomodoro language es       # en | es
omarchy-shell doro.pomodoro signIn github     # google | github | discord
omarchy-shell doro.pomodoro signOut
omarchy-shell doro.pomodoro dashboard         # abre doro.page/dashboard
omarchy-shell doro.pomodoro joinRoom https://doro.page/invitacion/AB12CD34   # o el código
omarchy-shell doro.pomodoro createRoom        # y copia el link de invitación
omarchy-shell doro.pomodoro copyRoomLink
omarchy-shell doro.pomodoro leaveRoom
```

Por ejemplo, en `~/.config/hypr/bindings.conf`:

```
bindd = SUPER ALT, P, Doro: arrancar o pausar, exec, omarchy-shell doro.pomodoro toggle
```

## Qué usa

- Corre dentro del proceso de `omarchy-shell`, sin servicios propios ni permisos extra.
- Sonido con QtMultimedia (`qt6-multimedia`, viene con Omarchy).
- Avisos con `omarchy-notification-send`, con el logo de Doro en el color del tema
  (`~/.local/state/doro/icono-aviso.svg`, que se reescribe al cambiar de tema).
- Escribe en `~/.local/state/doro/` (con permisos 700: `sesion.json` guarda los
  tokens) y, al entrar con una cuenta, el `.desktop` de `doro://`.
- Habla con el Supabase de doro.page por HTTPS (`/auth/v1`, `/rest/v1`,
  `/functions/v1/sumar-anonimo`) y, en una sala, por WebSocket (`/realtime/v1`). El
  proyecto y la clave anon van en las constantes de `Supabase.js`: la clave es pública
  (es la misma que viaja en la web) y lo que protege los datos son las políticas RLS.
  Para apuntar a otro proyecto, por ejemplo un Supabase local, sirven el `.env` del
  plugin (`DORO_SUPABASE_URL`, `DORO_SUPABASE_ANON_KEY`; ver `.env.example`,
  `scripts/instalar-local.sh` lo copia) o `~/.config/doro/supabase.json`
  (`{ "url": "…", "anonKey": "…" }`), que pisa a los dos. Sin proyecto configurado,
  el plugin funciona local y el panel no muestra la sección de cuenta.

## Desarrollo

Repo aparte de [Doro-Pomodoro](https://github.com/leonelcnr/Doro-Pomodoro) mientras el
plugin madura; no toca el repo de la web. El código está en español, como la web: la
lógica replica `src/store/timerStore.ts` y
`src/features/timer/hooks/useTimerActions.ts`, y los sonidos son copias de
`public/sounds` y `src/assets/sounds` (si cambian allá, hay que traerlos). Los textos
visibles están en `Textos.js`.

```sh
scripts/instalar-local.sh      # instala desde esta copia; la primera vez pregunta dónde va en la barra
node tests/model.test.mjs      # pruebas de la lógica del reloj y de las salas
node tests/supabase.test.mjs   # pruebas de la sesión, la cola y el resumen
node tests/textos.test.mjs     # que cada texto visible exista en inglés y en español
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

El shell recarga el widget al cambiar los archivos, pero el servicio
(`keepLoaded`) y el panel ya abierto pueden quedar con la versión vieja:
`omarchy-restart-shell` los recarga.

| Archivo | Qué hace |
|---|---|
| `Service.qml` | El reloj (uno por sesión), los sonidos, lo guardado, el idioma y el IPC |
| `BarWidget.qml` | La vista de la barra (una por monitor); le pasa el ajuste `language` al servicio |
| `Panel.qml` | El panel; los sonidos con la vista del mezclador de la web |
| `AnilloDoro.qml` | El logo de Doro dibujado con los colores del tema |
| `SonidoSinCortes.qml` | Un sonido ambiente en bucle sin cortes (dos reproductores desfasados con crossfade) |
| `Model.js` | La lógica pura del reloj, la misma de `timerStore`, y la del reloj compartido |
| `Nube.qml` | La sesión con doro.page, los pomodoros del dashboard (con cola sin conexión) y el resumen |
| `Sala.qml` | Entrar, crear y salir de salas; `timer_state` por Realtime o consultas cada 2 s |
| `Supabase.js` | La lógica pura de la sesión, la vuelta del OAuth, la cola y el resumen |
| `Textos.js` | Los textos visibles en inglés y español |

## Pendiente

- Probar contra el Supabase real: vincular un anónimo a una cuenta nueva y la
  renovación del token con una sala abierta más de una hora.
- Antes de publicar: sumar un `preview.png` (una captura del panel) en la raíz.

## Licencia

[MIT](LICENSE), © 2026 Daniel Emiliano Acevedo y Leonel Jeremias Canario.
