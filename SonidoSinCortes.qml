import QtQuick
import QtMultimedia

// Un sonido ambiente en bucle sin cortes. Hace lo mismo que
// `ReproductorAudioSinCortes` de la web (dos reproductores y un crossfade de
// potencia constante), pero sin detener ni mover nunca a ninguno.
//
// Medido grabando la salida:
//  - `loops: MediaPlayer.Infinite` solo deja 100 ms de silencio en cada vuelta.
//  - Turnar dos reproductores con play/stop, como la web, deja de vez en cuando
//    un hueco de 60 ms unos 2 s después de detener uno: el backend de FFmpeg
//    suelta el stream del reproductor quieto y el otro se corta un instante.
//
// Así que los dos suenan en bucle todo el tiempo, desfasados media vuelta. Cada
// uno se apaga al acercarse a su propia unión (donde está el hueco de Qt) y
// vuelve a subir después; como las uniones caen separadas, siempre hay uno
// sonando entero mientras el otro pasa por la suya.
Item {
  id: root

  property url fuente
  property real volumen: 0           // 0 a 1
  property bool reproduciendo: false

  // Lo mismo que la web: 2 s de fundido a cada lado de la unión.
  readonly property int crossfadeMs: 2000
  // Silencio de más alrededor de la unión, para tapar el hueco de 100 ms.
  readonly property int margenMs: 150

  readonly property real duracion: a.duration
  // B solo se puede adelantar media vuelta cuando ya cargó su archivo.
  readonly property bool listo: a.duration > 0 && b.duration > 0

  // Con archivos cortos el fundido se achica para que entre en media vuelta.
  function largoFundido() {
    return Math.max(100, Math.min(crossfadeMs, duracion / 2 - margenMs * 2))
  }

  // 0 en la unión, sube con un seno hasta 1 a `largoFundido` de distancia.
  function ganancia(posicion) {
    var aLaUnion = Math.min(posicion, duracion - posicion) - margenMs
    var t = Math.max(0, Math.min(1, aLaUnion / largoFundido()))
    return Math.sin(t * 0.5 * Math.PI)
  }

  function sonando(reproductor) {
    return reproductor.playbackState === MediaPlayer.PlayingState
  }

  function revisar() {
    if (!reproduciendo || volumen <= 0 || !listo) return

    if (!sonando(a)) a.play()
    if (!sonando(b)) b.play()
    // B va media vuelta adelante de A. Se corrige solo cuando se aleja más de un
    // cuarto de vuelta: al arrancar (el primer salto puede no aplicarse si el
    // archivo todavía no admite saltos) o si alguno se atrasó.
    var desfase = ((b.position - a.position) % duracion + duracion) % duracion
    if (Math.abs(desfase - duracion / 2) > duracion / 4 && b.seekable && sonando(b))
      b.position = (a.position + Math.round(duracion / 2)) % duracion

    // Potencia constante: las dos ganancias se normalizan para que la suma de
    // sus cuadrados sea 1, así el nivel no sube ni baja en el cruce.
    var ga = ganancia(a.position)
    var gb = ganancia(b.position)
    var norma = Math.sqrt(ga * ga + gb * gb)
    if (norma <= 0) {
      ga = 1
      gb = 0
      norma = 1
    }
    salidaA.volume = volumen * ga / norma
    salidaB.volume = volumen * gb / norma
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
