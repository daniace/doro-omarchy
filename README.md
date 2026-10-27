# Doro para Omarchy

El reloj Pomodoro de [doro.page](https://doro.page) como plugin de la barra de
[Omarchy](https://omarchy.org): sin abrir el navegador.

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

## Instalar

El repo es privado por ahora: `omarchy plugin add` lo clona con tu sesión de
GitHub (`gh auth login`).

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

```sh
omarchy-shell doro.pomodoro alternar        # arrancar / pausar
omarchy-shell doro.pomodoro reiniciar
omarchy-shell doro.pomodoro siguienteModo
omarchy-shell doro.pomodoro modo stopwatch  # pomodoro | shortBreak | longBreak | stopwatch
omarchy-shell doro.pomodoro volumen rain 40 # 0 lo apaga
omarchy-shell doro.pomodoro ambiente        # pausar / reanudar los sonidos
omarchy-shell doro.pomodoro panel           # abrir / cerrar el panel
omarchy-shell doro.pomodoro estado          # JSON con la fase y el tiempo
omarchy-shell doro.pomodoro probarAviso     # el aviso y la alarma de fin de pomodoro
omarchy-shell doro.pomodoro entrar github   # google | github | discord
omarchy-shell doro.pomodoro salir
omarchy-shell doro.pomodoro dashboard       # abre doro.page/dashboard
omarchy-shell doro.pomodoro unirse https://doro.page/invitacion/AB12CD34   # o el código
omarchy-shell doro.pomodoro crearSala       # y copia el link de invitación
omarchy-shell doro.pomodoro copiarLink
omarchy-shell doro.pomodoro salirSala
```

Por ejemplo, en `~/.config/hypr/bindings.conf`:

```
bindd = SUPER ALT, P, Doro: arrancar o pausar, exec, omarchy-shell doro.pomodoro alternar
```

## Qué usa

- Corre dentro del proceso de `omarchy-shell`, sin servicios propios ni permisos extra.
- Sonido con QtMultimedia (`qt6-multimedia`, viene con Omarchy).
- Avisos con `omarchy-notification-send`, con el logo de Doro en el color del tema
  (`~/.local/state/doro/icono-aviso.svg`, que se reescribe al cambiar de tema).
- Escribe en `~/.local/state/doro/` (con permisos 700: `sesion.json` guarda los
  tokens) y, al entrar con una cuenta, el `.desktop` de `doro://`.
- Habla con el Supabase de doro.page por HTTPS (`/auth/v1`, `/rest/v1`,
  `/functions/v1/sumar-anonimo`) y, en una sala, por WebSocket (`/realtime/v1`). El proyecto y la clave anon van en las
  constantes de `Supabase.js`: la clave es pública (es la misma que viaja en la web)
  y lo que protege los datos son las políticas RLS. Para apuntar a otro proyecto,
  por ejemplo un Supabase local, sirven el `.env` del plugin
  (`DORO_SUPABASE_URL`, `DORO_SUPABASE_ANON_KEY`; ver `.env.example`,
  `scripts/instalar-local.sh` lo copia) o `~/.config/doro/supabase.json`
  (`{ "url": "…", "anonKey": "…" }`), que pisa a los dos. Sin proyecto
  configurado, el plugin funciona local y el panel no muestra la sección de cuenta.

## Desarrollo

Repo aparte de [Doro-Pomodoro](https://github.com/leonelcnr/Doro-Pomodoro) mientras el
plugin madura; no toca el repo de la web. La lógica replica `src/store/timerStore.ts` y
`src/features/timer/hooks/useTimerActions.ts`, y los sonidos son copias de
`public/sounds` y `src/assets/sounds`: si cambian allá, hay que traerlos.

```sh
scripts/instalar-local.sh   # instala desde esta copia; la primera vez pregunta dónde va en la barra
node tests/model.test.mjs   # pruebas de la lógica del reloj
node tests/supabase.test.mjs   # pruebas de la sesión, la cola y el resumen
qs log -p "$OMARCHY_PATH/shell" --tail 100
```

El shell recarga el widget al cambiar los archivos, pero el servicio
(`keepLoaded`) y el panel ya abierto pueden quedar con la versión vieja:
`omarchy-restart-shell` los recarga.

| Archivo | Qué hace |
|---|---|
| `Service.qml` | El reloj (uno por sesión), los sonidos, lo guardado y el IPC |
| `BarWidget.qml` | La vista de la barra (una por monitor) |
| `Panel.qml` | El panel; los sonidos con la vista del mezclador de la web |
| `AnilloDoro.qml` | El logo de Doro dibujado con los colores del tema |
| `SonidoSinCortes.qml` | Un sonido ambiente en bucle sin cortes (dos reproductores desfasados con crossfade) |
| `Model.js` | La lógica pura del reloj, la misma de `timerStore`, y la del reloj compartido |
| `Nube.qml` | La sesión con doro.page, los pomodoros del dashboard (con cola sin conexión) y el resumen |
| `Sala.qml` | Entrar, crear y salir de salas; `timer_state` por Realtime o consultas cada 2 s |
| `Supabase.js` | La lógica pura de la sesión, la vuelta del OAuth, la cola y el resumen |

## Pendiente

- Probar contra el Supabase real: vincular un anónimo a una cuenta nueva y la
  renovación del token con una sala abierta más de una hora.
- Antes de publicar: sumar un `preview.png` (una captura del panel) arriba del README.

## Licencia

[MIT](LICENSE), © 2026 Daniel Emiliano Acevedo y Leonel Jeremias Canario.
