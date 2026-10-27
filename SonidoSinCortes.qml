import QtQuick
import QtMultimedia

// Un sonido ambiente en bucle sin cortes. Hace lo mismo que
// `ReproductorAudioSinCortes` de la web (se turnan dos reproductores, con un
// crossfade de potencia constante en la unión), pero sin detener nunca a ninguno.
//
// Medido grabando la salida:
//  - `loops: MediaPlayer.Infinite` solo deja 100 ms de silencio en cada vuelta.
//  - Turnar dos reproductores con play/stop, como la web, deja de vez en cuando
//    un hueco de 60 ms unos 2 s después de detener uno: el backend de FFmpeg
//    suelta el stream del reproductor quieto y el otro se corta un instante.
//
// Así que los dos suenan en bucle todo el tiempo, pero se escucha uno solo: el
// principal. Antes de que llegue a su unión (donde está el hueco de Qt), el otro,
// callado, salta al principio del archivo y sube mientras el principal baja;
// después pasa a ser el principal. Que suenen los dos a la vez solo en el cruce
// importa con la música (el jazz): desfasados todo el tiempo se oía dos veces.
Item {
  id: root

  property url fuente
  property real volumen: 0           // 0 a 1
  property bool reproduciendo: false

  // Lo mismo que la web: 2 s de crossfade antes de la unión.
  readonly property int crossfadeMs: 2000
  // El cruce termina este margen antes de la unión, para no pisar el hueco de 100 ms.
  readonly property int margenMs: 150
  // El salto del que entra se hace un poco antes del cruce, para que ya esté sonando.
  readonly property int anticipoMs: 300

  readonly property real duracion: a.duration
  readonly property bool listo: a.duration > 0 && b.duration > 0

  // Cuál se escucha: true, A; false, B.
  property bool principalEsA: true
  // El que entra ya saltó al principio para este cruce.
  property bool entranteListo: false
  property real posicionAnterior: 0

  readonly property var principal: principalEsA ? a : b
  readonly property var entrante: principalEsA ? b : a

  // Con archivos cortos el fundido se achica para que entre en media vuelta.
  function largoFundido() {
    return Math.max(100, Math.min(crossfadeMs, duracion / 2 - margenMs * 2))
  }

  function sonando(reproductor) {
    return reproductor.playbackState === MediaPlayer.PlayingState
  }

  function salidaDe(reproductor) {
    return reproductor === a ? salidaA : salidaB
  }

  function cambiarPrincipal() {
    principalEsA = !principalEsA
    entranteListo = false
    posicionAnterior = principal.position
  }

  function revisar() {
    if (!reproduciendo || volumen <= 0 || !listo) return

    if (!sonando(a)) a.play()
    if (!sonando(b)) b.play()

    var fundido = largoFundido()
    var inicioCruce = duracion - margenMs - fundido
    var posicion = principal.position

    // El principal dio la vuelta sin que se completara el cruce (el sistema
    // estuvo ocupado): el entrante ya venía sonando desde el principio, pasa a ser
    // el principal.
    if (posicion < posicionAnterior - duracion / 2 && entranteListo) {
      cambiarPrincipal()
      posicion = principal.position
      fundido = largoFundido()
    }
    posicionAnterior = posicion

    if (!entranteListo && posicion >= inicioCruce - anticipoMs && entrante.seekable) {
      entrante.position = 0
      entranteListo = true
    }

    // Potencia constante: coseno y seno, la suma de sus cuadrados es 1.
    var t = entranteListo ? Math.max(0, Math.min(1, (posicion - inicioCruce) / fundido)) : 0
    salidaDe(principal).volume = volumen * Math.cos(t * 0.5 * Math.PI)
    salidaDe(entrante).volume = volumen * Math.sin(t * 0.5 * Math.PI)

    if (t >= 1) cambiarPrincipal()
  }

  function detener() {
    a.pause()
    b.pause()
  }

  // Con el volumen o la pausa no se espera al próximo tick: la barra responde al toque.
  onVolumenChanged: volumen > 0 ? revisar() : detener()
  onReproduciendoChanged: reproduciendo ? revisar() : detener()
  onListoChanged: revisar()

  onFuenteChanged: {
    a.stop()
    b.stop()
    principalEsA = true
    entranteListo = false
    posicionAnterior = 0
  }

  // Cada 50 ms: el volumen sigue a la posición y el fundido no se escalona.
  Timer {
    interval: 50
    repeat: true
    running: root.reproduciendo && root.volumen > 0 && root.listo
    onTriggered: root.revisar()
  }

  MediaPlayer {
    id: a
    source: root.fuente
    loops: MediaPlayer.Infinite
    audioOutput: AudioOutput { id: salidaA; volume: 0 }
  }

  MediaPlayer {
    id: b
    source: root.fuente
    loops: MediaPlayer.Infinite
    audioOutput: AudioOutput { id: salidaB; volume: 0 }
  }
}
