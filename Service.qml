import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model
import "Textos.js" as Textos

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

  readonly property string idPlugin: "doro.pomodoro"
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

  // ---- Idioma de lo visible: el ajuste `language` del widget (lo pasa la
  //      barra) o, sin ajuste, el del sistema. Ver `Textos.js`.
  property string idiomaAjuste: ""
  readonly property string idioma: Textos.idiomaElegido(idiomaAjuste,
    Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG"))

  function t(clave, valores) { return Textos.t(idioma, clave, valores) }

  // Lo guarda en el ajuste del widget en shell.json, como `omarchy bar set`;
  // la barra lo devuelve en `idiomaAjuste`.
  function establecerIdioma(nuevo) {
    if (Textos.IDIOMAS.indexOf(nuevo) === -1) return
    idiomaAjuste = nuevo
    Quickshell.execDetached(["omarchy", "bar", "set", idPlugin, "language", nuevo])
  }

  readonly property string etiquetaModo: t("modo." + modo)
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
    cambioLocal()
  }

  function pausar() {
    if (!estaActivo) return
    actualizar()
    estaActivo = false
    tiempoFinObjetivo = 0
    tiempoInicioCronometro = 0
    guardar()
    cambioLocal()
  }

  // Igual que `manejarReinicio` de la web: el cronómetro vuelve a 0 y el
  // temporizador vuelve al pomodoro.
  function reiniciar() {
    if (modo === "stopwatch") {
      estaActivo = false
      tiempoInicioCronometro = 0
      tiempoRestante = 0
      guardar()
      cambioLocal()
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
    cambioLocal()
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
    cambioLocal()
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
    // Como la web: cuenta el pomodoro con sus minutos configurados (los descansos no).
    if (terminado === "pomodoro") nube.registrarPomodoro(configuracion.pomodoro)
    establecerModo(Model.modoAlTerminar(terminado))
    if (configuracion.autoBreak) iniciar()
  }

  function sonar(reproductor) {
    reproductor.stop()
    reproductor.play()
  }

  function avisar(terminado) {
    var aviso = Textos.aviso(idioma, terminado)
    notificar(aviso.titulo, aviso.cuerpo)
  }

  function notificar(titulo, cuerpo) {
    Quickshell.execDetached(["omarchy-notification-send", "--app-name", "Doro", "--image", rutaIconoAviso,
      titulo, cuerpo])
  }

  // ---- doro.page: la sesión, los pomodoros del dashboard y el resumen.
  property alias nube: nube

  Nube {
    id: nube
    carpetaEstado: root.carpetaEstado
    idioma: root.idioma
    onAviso: function(titulo, cuerpo) { root.notificar(titulo, cuerpo) }
  }

  // ---- La sala: el reloj compartido. Cada acción local se sube (agrupadas: una
  //      acción puede llamar a otras) y lo remoto se aplica sin volver a subirse.
  property alias sala: sala
  property bool aplicandoRemoto: false

  Sala {
    id: sala
    nube: nube
    idioma: root.idioma
    onEstadoRecibido: function(estado) { root.aplicarRemoto(estado) }
    onAviso: function(titulo, cuerpo) { root.notificar(titulo, cuerpo) }
    onCambio: root.guardar()
  }

  function cambioLocal() {
    if (cargado && !aplicandoRemoto && sala.unida) subida.restart()
  }

  function estadoLocal() {
    return Model.estadoParaSubir({
      tiempoRestante: tiempoRestante, estaActivo: estaActivo, modo: modo, configuracion: configuracion,
      tiempoFinObjetivo: tiempoFinObjetivo, tiempoInicioCronometro: tiempoInicioCronometro
    }, Date.now())
  }

  Timer {
    id: subida
    interval: 50
    onTriggered: root.sala.subir(root.estadoLocal())
  }

  function crearSala() { sala.crear(estadoLocal()) }

  // Lo que estaba por subirse (por ejemplo, pausar justo antes) sale antes de
  // irse; si no, la sala quedaría corriendo para los demás.
  function salirSala() {
    if (subida.running) {
      subida.stop()
      sala.subir(estadoLocal())
    }
    sala.salir()
  }

  function aplicarRemoto(remoto) {
    var estado = Model.aplicarRemoto(remoto, configuracion, Date.now())
    aplicandoRemoto = true
    configuracion = estado.configuracion
    modo = estado.modo
    tiempoInicial = estado.tiempoInicial
    tiempoFinObjetivo = estado.vencido ? 0 : estado.tiempoFinObjetivo
    tiempoInicioCronometro = estado.tiempoInicioCronometro
    tiempoRestante = estado.vencido ? 0 : estado.tiempoRestante
    estaActivo = estado.estaActivo && !estado.vencido
    aplicandoRemoto = false
    guardar()
    // Una fase que terminó sin nadie que la cerrara pasa a la siguiente, sin
    // alarma ni pomodoro: no la hizo este reloj.
    if (estado.vencido) establecerModo(Model.modoAlTerminar(estado.modo))
  }

  // ---- El ícono del aviso: el logo de Doro en el color del texto de las
  //      notificaciones del tema. Omarchy no tiñe una imagen pasada por ruta,
  //      así que se escribe con el color puesto y se reescribe al cambiar de tema.
  readonly property string rutaIconoAviso: carpetaEstado + "/icono-aviso.svg"
  readonly property color colorAviso: Color.notifications.text

  function escribirIconoAviso() {
    iconoAviso.setText(Model.svgLogo(colorAviso.r * 255, colorAviso.g * 255, colorAviso.b * 255, colorAviso.a))
  }

  onColorAvisoChanged: if (cargado) escribirIconoAviso()

  FileView {
    id: iconoAviso
    path: root.rutaIconoAviso
    atomicWrites: true
    printErrors: false
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

  // Un reproductor sin cortes por sonido ambiente; sin volumen no carga el archivo.
  Instantiator {
    model: root.sonidosAmbiente

    delegate: SonidoSinCortes {
      required property var modelData
      readonly property int nivel: root.mezcla[modelData.id] || 0
      readonly property bool conVolumen: nivel > 0

      // Depende de `conVolumen` y no del nivel: reasignar la misma URL hace que
      // MediaPlayer recargue el archivo y se detenga, y eso pasaba en cada
      // movimiento del slider. Un bool solo avisa cuando cambia de verdad.
      fuente: conVolumen ? Qt.resolvedUrl("sounds/" + modelData.archivo) : ""
      volumen: nivel / 100
      reproduciendo: root.ambienteActivo && conVolumen
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
        mezcla: root.mezcla,
        sala: root.sala.salaId ? { id: root.sala.salaId, codigo: root.sala.codigo } : null
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
    // Como la web al volver a la sala: se reengancha y el estado de la sala manda.
    if (estado.sala && !sala.salaId) sala.entrar(estado.sala.id, estado.sala.codigo)
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
    onExited: {
      archivo.reload()
      root.escribirIconoAviso()
      nube.cargar()
    }
  }

  Component.onCompleted: crearCarpeta.running = true

  // ---- IPC: `omarchy-shell doro.pomodoro <función>`.
  //      Abrir el panel es cosa del widget, así que se le pasa al shell, que lo
  //      rutea al monitor con foco.

  function invocarVista(accion) {
    if (!shell || typeof shell[accion] !== "function") return
    shell[accion](idPlugin, "{}")
  }

  // El panel abierto en una sección: lo escuchan los paneles de cada monitor.
  signal seccionPedida(string nombre)

  // Los nombres del IPC (en inglés) y los de las secciones del panel.
  readonly property var secciones: ({ timer: "", times: "tiempos", sounds: "sonidos", room: "sala" })

  function abrirSeccion(nombre) {
    if (!(nombre in secciones)) return
    seccionPedida(secciones[nombre])
    invocarVista("summon")
  }

  // La API es en inglés: es lo que la gente pone en sus atajos y scripts.
  ShellIpc {
    target: root.idPlugin

    function toggle(): void { root.alternar() }
    function start(): void { root.iniciar() }
    function pause(): void { root.pausar() }
    function reset(): void { root.reiniciar() }
    function nextMode(): void { root.siguienteModo() }
    function mode(nuevo: string): void { root.establecerModo(nuevo) }
    function toggleAmbient(): void { root.alternarAmbiente() }
    function volume(id: string, valor: int): void { root.establecerVolumen(id, valor) }
    // The end-of-pomodoro notification and alarm, without touching the timer.
    function testNotification(): void { root.sonar(alarma); root.avisar("pomodoro") }
    function status(): string {
      return JSON.stringify({ mode: root.modo, running: root.estaActivo, remaining: root.tiempoRestante, text: root.texto,
        language: root.idioma, user: nube.usuario ? { id: nube.usuario.id, anonymous: nube.usuario.anonimo, name: nube.usuario.nombre } : null,
        pending: nube.pendientes.length, connected: nube.configurada,
        room: sala.salaId ? { id: sala.salaId, code: sala.codigo, link: sala.link, joined: sala.unida, live: sala.enVivo } : null })
    }
    function language(codigo: string): void { root.establecerIdioma(codigo) }
    // Rooms: `joinRoom <link or code>`, `createRoom` (copies the link), `copyRoomLink`, `leaveRoom`.
    function joinRoom(texto: string): void { sala.unirse(texto) }
    function createRoom(): void { root.crearSala() }
    function copyRoomLink(): void { sala.copiarLink() }
    function leaveRoom(): void { root.salirSala() }
    // doro.page: `signIn google|github|discord`, `signOut`, and `authCallback <url>`,
    // the browser coming back through `doro://auth`.
    function signIn(proveedor: string): void { nube.entrar(proveedor) }
    function signOut(): void { nube.salir() }
    function authCallback(url: string): void { nube.recibirRetorno(url) }
    function dashboard(): void { nube.abrirDashboard() }
    function open(): void { root.invocarVista("summon") }
    function close(): void { root.invocarVista("hide") }
    function panel(): void { root.invocarVista("toggle") }
    // The panel open on `times`, `sounds` or `room` (`timer`: just the clock).
    function section(nombre: string): void { root.abrirSeccion(nombre) }
  }
}
