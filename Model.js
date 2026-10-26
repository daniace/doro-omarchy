.pragma library

// Lógica pura del reloj de Doro para Omarchy, sin QML, para poder probarla aparte.
//
// Replica el comportamiento de la web (`src/store/timerStore.ts` y
// `src/features/timer/hooks/useTimerActions.ts`). Los VALORES de `modo` y las
// CLAVES de la configuración quedan en inglés por el mismo motivo que allá: se
// indexan entre sí (`configuracion[modo]`) y son el contrato de `timer_state`,
// así que una futura sincronización con las salas no tiene que traducir nada.

var MODOS = ["pomodoro", "shortBreak", "longBreak", "stopwatch"]

var CONFIGURACION_INICIAL = { pomodoro: 25, shortBreak: 5, longBreak: 15, autoBreak: false }

// Topes de minutos por fase, los mismos del panel de tiempos de la web (`PanelTiempos`).
var MAXIMOS = { pomodoro: 180, shortBreak: 60, longBreak: 90 }

// Por encima de esto asumimos un estado guardado corrupto (igual que la web).
var MAX_SEGUNDOS_VALIDOS = 24 * 60 * 60

var ETIQUETA_MODO = {
  pomodoro: "Pomodoro",
  shortBreak: "Descanso corto",
  longBreak: "Descanso largo",
  stopwatch: "Cronómetro"
}

// Catálogo de sonidos ambientales: mismos `id` y archivos que
// `src/features/room/components/music/ambientSounds.ts`. Los íconos son Nerd Font
// (Material Design) en vez de lucide.
var SONIDOS_AMBIENTE = [
  { id: "rain", nombre: "Lluvia", icono: "\u{f0597}", archivo: "rain.ogg" },
  { id: "fire", nombre: "Fogata", icono: "\u{f0238}", archivo: "fire.ogg" },
  { id: "ocean", nombre: "Océano", icono: "\u{f078d}", archivo: "ocean.ogg" },
  { id: "thunder", nombre: "Truenos", icono: "\u{f0593}", archivo: "thunder.ogg" },
  { id: "people", nombre: "Personas", icono: "\u{f0849}", archivo: "people.ogg" },
  { id: "traffic", nombre: "Tráfico", icono: "\u{f010b}", archivo: "traffic.ogg" },
  { id: "train", nombre: "Tren", icono: "\u{f052c}", archivo: "train.ogg" },
  { id: "keyboard", nombre: "Teclado", icono: "\u{f030c}", archivo: "keyboard.ogg" },
  { id: "birds", nombre: "Pájaros", icono: "\u{f15c6}", archivo: "birds.ogg" },
  { id: "brown_noise", nombre: "Ruido marrón", icono: "\u{f0430}", archivo: "brown_noise.ogg" },
  { id: "jazz", nombre: "Jazz", icono: "\u{f075a}", archivo: "jazz.ogg" },
  { id: "underwater", nombre: "Subacuático", icono: "\u{f058c}", archivo: "white-noise-underwater.ogg" }
]

function esModo(modo) {
  return MODOS.indexOf(modo) !== -1
}

/** Duración en segundos de una fase; el cronómetro arranca en 0. */
function duracionModo(modo, configuracion) {
  if (modo === "stopwatch") return 0
  return (Number(configuracion[modo]) || CONFIGURACION_INICIAL[modo]) * 60
}

/** Fase a la que se pasa sola al terminar la actual (la web no cuenta rondas). */
function modoAlTerminar(modo) {
  return modo === "pomodoro" ? "shortBreak" : "pomodoro"
}

/** Fase a la que se pasa al tocar el nombre (`manejarClickModo` en `TimerDisplay`). */
function modoSiguiente(modo) {
  if (modo === "pomodoro") return "shortBreak"
  if (modo === "shortBreak") return "longBreak"
  return "pomodoro"
}

/** Minutos acotados a lo que acepta cada fase (de 1 al máximo). */
function acotarMinutos(clave, minutos) {
  return Math.max(1, Math.min(MAXIMOS[clave], Math.round(Number(minutos) || 1)))
}

/** MM:SS siempre en minutos (60 minutos se ven «60:00»), con tope en 5999:59. */
function formatear(segundos) {
  var total = Math.min(5999 * 60 + 59, Math.max(0, Math.floor(Number(segundos)) || 0))
  var minutos = Math.floor(total / 60)
  var resto = total % 60
  return (minutos < 10 ? "0" : "") + minutos + ":" + (resto < 10 ? "0" : "") + resto
}

/** 0 a 1, lo que ya pasó de la fase; null en el cronómetro, que no tiene tope. */
function avance(modo, tiempoRestante, tiempoInicial) {
  if (modo === "stopwatch" || tiempoInicial <= 0) return null
  return Math.max(0, Math.min(1, 1 - tiempoRestante / tiempoInicial))
}

/**
 * Ticks de los últimos segundos: suena al cruzar los 10 y los 5, detectando saltos
 * (si el shell estuvo ocupado y el segundo anterior quedó atrás), como en la web.
 */
function suenaTick(anterior, actual) {
  var cruzo10 = anterior > 10 && actual <= 10
  var cruzo5 = anterior > 5 && actual <= 5
  return (cruzo10 && actual > 5) || cruzo5
}

function aviso(modoTerminado) {
  if (modoTerminado === "pomodoro")
    return { titulo: "Terminó el pomodoro", cuerpo: "Tomate un descanso." }
  return { titulo: "Terminó el descanso", cuerpo: "A enfocarse de nuevo." }
}

/**
 * El logo de Doro (`public/doro.svg`) en un color dado, para el ícono del aviso.
 * Las notificaciones de Omarchy muestran la imagen tal cual, sin teñirla con el
 * tema, así que el color viene ya puesto: `rgb` de 0 a 255 y `opacidad` de 0 a 1.
 */
function svgLogo(r, g, b, opacidad) {
  var trazo = "rgb(" + Math.round(r) + "," + Math.round(g) + "," + Math.round(b) + ")"
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="' + trazo + '"' +
    ' stroke-opacity="' + opacidad + '" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">\n' +
    '  <path d="M5.636 5.636a9 9 0 1 1 12.728 12.728a9 9 0 0 1 -12.728 -12.728z" />\n' +
    '  <path d="M16.243 7.757a6 6 0 0 0 -8.486 0" />\n' +
    '</svg>\n'
}

/**
 * Lee el estado guardado y lo sanea. Como la web al rehidratar, nunca reanuda un
 * reloj que había quedado corriendo: vuelve en pausa con el tiempo que tenía.
 */
function estadoGuardado(texto) {
  var datos = {}
  try {
    datos = JSON.parse(texto || "{}") || {}
  } catch (e) {
    datos = {}
  }

  var configuracion = {
    pomodoro: CONFIGURACION_INICIAL.pomodoro,
    shortBreak: CONFIGURACION_INICIAL.shortBreak,
    longBreak: CONFIGURACION_INICIAL.longBreak,
    autoBreak: CONFIGURACION_INICIAL.autoBreak
  }
  var guardada = datos.configuracion || {}
  for (var clave in MAXIMOS)
    if (guardada[clave] !== undefined) configuracion[clave] = acotarMinutos(clave, guardada[clave])
  if (typeof guardada.autoBreak === "boolean") configuracion.autoBreak = guardada.autoBreak

  var modo = esModo(datos.modo) ? datos.modo : "pomodoro"
  var tiempoInicial = duracionModo(modo, configuracion)
  var tiempoRestante = Number(datos.tiempoRestante)
  var valido = isFinite(tiempoRestante) && tiempoRestante >= 0 && tiempoRestante <= MAX_SEGUNDOS_VALIDOS
  if (!valido || (modo !== "stopwatch" && tiempoRestante > tiempoInicial)) tiempoRestante = tiempoInicial

  var mezcla = {}
  var mezclaGuardada = datos.mezcla || {}
  for (var i = 0; i < SONIDOS_AMBIENTE.length; i++) {
    var id = SONIDOS_AMBIENTE[i].id
    var volumen = Number(mezclaGuardada[id])
    if (volumen > 0) mezcla[id] = Math.min(100, Math.round(volumen))
  }

  return {
    configuracion: configuracion,
    modo: modo,
    tiempoInicial: tiempoInicial,
    tiempoRestante: Math.round(tiempoRestante),
    mezcla: mezcla
  }
}
