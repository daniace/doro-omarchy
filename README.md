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

Esta primera versión es local: no inicia sesión ni entra a salas.

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
omarchy bar move page.doro.pomodoro --section right   # left | centerBegin | center | centerEnd | tray | right
```

## Atajos y scripts (IPC)

```sh
omarchy-shell page.doro.pomodoro alternar        # arrancar / pausar
omarchy-shell page.doro.pomodoro reiniciar
omarchy-shell page.doro.pomodoro siguienteModo
omarchy-shell page.doro.pomodoro modo stopwatch  # pomodoro | shortBreak | longBreak | stopwatch
omarchy-shell page.doro.pomodoro volumen rain 40 # 0 lo apaga
omarchy-shell page.doro.pomodoro ambiente        # pausar / reanudar los sonidos
omarchy-shell page.doro.pomodoro panel           # abrir / cerrar el panel
omarchy-shell page.doro.pomodoro estado          # JSON con la fase y el tiempo
```

Por ejemplo, en `~/.config/hypr/bindings.conf`:

```
bindd = SUPER ALT, P, Doro: arrancar o pausar, exec, omarchy-shell page.doro.pomodoro alternar
```

## Qué usa

- Corre dentro del proceso de `omarchy-shell`, sin servicios propios ni permisos extra.
- Sonido con QtMultimedia (`qt6-multimedia`, viene con Omarchy).
- Avisos con `omarchy-notification-send`.
- Escribe solo en `~/.local/state/doro/`.

## Desarrollo

Repo aparte de [Doro-Pomodoro](https://github.com/leonelcnr/Doro-Pomodoro) mientras el
plugin madura; no toca el repo de la web. La lógica replica `src/store/timerStore.ts` y
`src/features/timer/hooks/useTimerActions.ts`, y los sonidos son copias de
`public/sounds` y `src/assets/sounds`: si cambian allá, hay que traerlos.

```sh
scripts/instalar-local.sh   # instala desde esta copia; la primera vez pregunta dónde va en la barra
node tests/model.test.mjs   # pruebas de la lógica del reloj
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
| `Model.js` | La lógica pura del reloj, la misma de `timerStore` |

## Pendiente

- Entrar a una sala de Doro y sincronizar el reloj (Supabase Realtime).
- Guardar los pomodoros terminados en las estadísticas de la cuenta.
- Bucle sin cortes en los sonidos ambiente (la web hace un crossfade; acá
  `MediaPlayer` repite el archivo).
- Licencia: el repo de la web no tiene, hay que definirla con el desarrollador.
- Antes de publicar: confirmar el id `page.doro.pomodoro` (no se puede cambiar
  después) y sumar un `preview.png`.
