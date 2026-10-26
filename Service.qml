import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

// El reloj de Doro, uno por sesión del shell.
//
// La barra crea un widget por monitor, así que el estado no puede vivir en el
// widget: con dos pantallas habría dos relojes que se desfasan y dos alarmas.
// El shell carga un `service` una sola vez; acá viven el reloj, los sonidos, lo
// guardado y el destino IPC, y cada widget y panel es solo una vista.
Item {
  id: root

  // Los inyecta el shell al crear el servicio.
  property var shell: null
  property var manifest: null

  readonly property string idPlugin: "page.doro.pomodoro"
  readonly property string carpetaEstado: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/doro"

  // ---- Estado del reloj (mismos nombres que `timerStore` de la web)
  property var configuracion: ({ pomodoro: 25, shortBreak: 5, longBreak: 15, autoBreak: false })
  property string modo: "pomodoro"
  property int tiempoInicial: Model.duracionModo(modo, configuracion)
  property int tiempoRestante: tiempoInicial
  property bool estaActivo: false
  // Anclas en milisegundos: el fin del temporizador o el inicio del cronómetro.
  // El tiempo se recalcula desde acá, así una suspensión no lo hace derivar.
  property real tiempoFinObjetivo: 0
  property real tiempoInicioCronometro: 0

  readonly property string etiquetaModo: Model.ETIQUETA_MODO[modo]
  readonly property string texto: Model.formatear(tiempoRestante)
  readonly property var avance: Model.avance(modo, tiempoRestante, tiempoInicial)
  // Todavía no arrancó la fase: la barra muestra solo el anillo.
  readonly property bool sinEmpezar: !estaActivo && tiempoRestante === tiempoInicial

  // ---- Sonidos ambientales (local, como `useAudioAmbiente` de la web)
  property var mezcla: ({})
  property bool ambienteActivo: true
  readonly property var sonidosAmbiente: Model.SONIDOS_AMBIENTE
  readonly property bool hayAmbienteActivo: {
    if (!ambienteActivo) return false
    for (var id in mezcla) if (mezcla[id] > 0) return true
    return false
  }

  property bool cargado: false

  // ---- Acciones

  function alternar() {
    if (estaActivo) pausar()
    else iniciar()
  }

  function iniciar() {
    if (estaActivo) return
    if (modo === "stopwatch") tiempoInicioCronometro = Date.now() - tiempoRestante * 1000
    else {
      // Una fase que terminó en pausa vuelve a empezar desde su duración.
      if (tiempoRestante <= 0) tiempoRestante = tiempoInicial
      tiempoFinObjetivo = Date.now() + tiempoRestante * 1000
    }
    estaActivo = true
  }

  function pausar() {
    if (!estaActivo) return
    actualizar()
    estaActivo = false
    tiempoFinObjetivo = 0
    tiempoInicioCronometro = 0
    guardar()
  }

  // Igual que `manejarReinicio` de la web: el cronómetro vuelve a 0 y el
  // temporizador vuelve al pomodoro.
  function reiniciar() {
    if (modo === "stopwatch") {
      estaActivo = false
      tiempoInicioCronometro = 0
      tiempoRestante = 0
      guardar()
    } else {
      establecerModo("pomodoro")
    }
  }

  function establecerModo(nuevo) {
    if (!Model.esModo(nuevo)) return
    estaActivo = false
    tiempoFinObjetivo = 0
    tiempoInicioCronometro = 0
    modo = nuevo
    tiempoInicial = Model.duracionModo(nuevo, configuracion)
    tiempoRestante = tiempoInicial
    guardar()
  }

  function siguienteModo() { establecerModo(Model.modoSiguiente(modo)) }
  function alternarCronometro() { establecerModo(modo === "stopwatch" ? "pomodoro" : "stopwatch") }

  function establecerMinutos(clave, minutos) {
    var acotado = Model.acotarMinutos(clave, minutos)
    if (acotado === configuracion[clave]) return
    var nueva = Object.assign({}, configuracion)
    nueva[clave] = acotado
    aplicarConfiguracion(nueva)
  }

  function establecerAutoBreak(valor) {
    var nueva = Object.assign({}, configuracion)
    nueva.autoBreak = !!valor
    aplicarConfiguracion(nueva)
  }

  // Con el reloj en pausa, la nueva duración se ve al toque (como en la web).
  function aplicarConfiguracion(nueva) {
    configuracion = nueva
    if (!estaActivo && modo !== "stopwatch") {
      tiempoInicial = Model.duracionModo(modo, nueva)
      tiempoRestante = tiempoInicial
    }
    guardar()
  }

  function establecerVolumen(id, valor) {
    var nueva = Object.assign({}, mezcla)
    var volumen = Math.max(0, Math.min(100, Math.round(valor)))
    if (volumen > 0) nueva[id] = volumen
    else delete nueva[id]
    mezcla = nueva
    if (volumen > 0) ambienteActivo = true
    guardar()
  }

  function alternarAmbiente() { ambienteActivo = !ambienteActivo }

  // ---- Conteo

  function actualizar() {
    if (!estaActivo) return
    var ahora = Date.now()
    if (modo === "stopwatch") {
      tiempoRestante = Math.max(0, Math.floor((ahora - tiempoInicioCronometro) / 1000))
      return
    }
    var anterior = tiempoRestante
    var restantes = Math.max(0, Math.ceil((tiempoFinObjetivo - ahora) / 1000))
    if (restantes <= 0) {
      terminarFase()
      return
    }
    if (Model.suenaTick(anterior, restantes)) sonar(tick)
    tiempoRestante = restantes
  }

  function terminarFase() {
    var terminado = modo
    tiempoRestante = 0
    sonar(alarma)
    avisar(terminado)
    establecerModo(Model.modoAlTerminar(terminado))
    if (configuracion.autoBreak) iniciar()
  }

  function sonar(reproductor) {
    reproductor.stop()
    reproductor.play()
  }

  function avisar(terminado) {
    var aviso = Model.aviso(terminado)
    Quickshell.execDetached(["omarchy-notification-send", aviso.titulo, aviso.cuerpo])
  }

  Timer {
    // 200 ms como la web: el cálculo es exacto, esto es solo para que el
    // segundo cambie a tiempo.
    interval: 200
    repeat: true
    running: root.estaActivo
    triggeredOnStart: true
    onTriggered: root.actualizar()
  }

  MediaPlayer {
    id: alarma
    source: Qt.resolvedUrl("sounds/alarm.mp3")
    audioOutput: AudioOutput { volume: 0.5 }
  }

  MediaPlayer {
    id: tick
    source: Qt.resolvedUrl("sounds/tick.mp3")
    audioOutput: AudioOutput { volume: 0.4 }
  }

  // Un reproductor por sonido ambiente; sin volumen no carga el archivo.
  Instantiator {
    model: root.sonidosAmbiente

    delegate: MediaPlayer {
      required property var modelData
      readonly property int volumen: root.mezcla[modelData.id] || 0
      readonly property bool conVolumen: volumen > 0
      readonly property bool debeSonar: root.ambienteActivo && conVolumen

      // Depende de `conVolumen` y no de `volumen`: reasignar la misma URL hace que
      // MediaPlayer recargue el archivo y se detenga, y eso pasaba en cada
      // movimiento del slider. Un bool solo avisa cuando cambia de verdad.
      source: conVolumen ? Qt.resolvedUrl("sounds/" + modelData.archivo) : ""
      loops: MediaPlayer.Infinite
      audioOutput: AudioOutput { volume: volumen / 100 }

      onDebeSonarChanged: debeSonar ? play() : pause()
      onSourceChanged: if (debeSonar) play()
    }
  }

  // ---- Lo guardado: configuración, fase, tiempo en pausa y la mezcla.
  //      Como la web al rehidratar, un reloj que quedó corriendo vuelve en pausa.

  function guardar() {
    if (cargado) guardado.restart()
  }

  Timer {
    id: guardado
    interval: 400
    onTriggered: {
      archivo.setText(JSON.stringify({
        configuracion: root.configuracion,
        modo: root.modo,
        tiempoRestante: root.tiempoRestante,
        mezcla: root.mezcla
      }, null, 2) + "\n")
    }
  }

  function aplicarGuardado(texto) {
    var estado = Model.estadoGuardado(texto)
    configuracion = estado.configuracion
    modo = estado.modo
    tiempoInicial = estado.tiempoInicial
    tiempoRestante = estado.tiempoRestante
    mezcla = estado.mezcla
    cargado = true
  }

  FileView {
    id: archivo
    path: root.carpetaEstado + "/omarchy.json"
    atomicWrites: true
    printErrors: false
    onLoaded: root.aplicarGuardado(text())
    onLoadFailed: root.aplicarGuardado("")
  }

  Process {
    id: crearCarpeta
    command: ["mkdir", "-p", root.carpetaEstado]
    onExited: archivo.reload()
  }

  Component.onCompleted: crearCarpeta.running = true

  // ---- IPC: `omarchy-shell page.doro.pomodoro <función>`.
  //      Abrir el panel es cosa del widget, así que se le pasa al shell, que lo
  //      rutea al monitor con foco.

  function invocarVista(accion) {
    if (!shell || typeof shell[accion] !== "function") return
    shell[accion](idPlugin, "{}")
  }

  ShellIpc {
    target: root.idPlugin

    function alternar(): void { root.alternar() }
    function iniciar(): void { root.iniciar() }
    function pausar(): void { root.pausar() }
    function reiniciar(): void { root.reiniciar() }
    function siguienteModo(): void { root.siguienteModo() }
    function modo(nuevo: string): void { root.establecerModo(nuevo) }
    function ambiente(): void { root.alternarAmbiente() }
    function volumen(id: string, valor: int): void { root.establecerVolumen(id, valor) }
    function estado(): string {
      return JSON.stringify({ modo: root.modo, estaActivo: root.estaActivo, tiempoRestante: root.tiempoRestante, texto: root.texto })
    }
    function abrir(): void { root.invocarVista("summon") }
    function cerrar(): void { root.invocarVista("hide") }
    function panel(): void { root.invocarVista("toggle") }
  }
}
