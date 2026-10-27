import QtQuick
import Quickshell
import "Model.js" as Model
import "Supabase.js" as Supabase
import "Textos.js" as Textos

// La sala de doro.page en la que está el reloj: entrar por link o código, crear
// una y mantener `rooms.timer_state` sincronizado, como `useSincronizacionReloj`
// de la web. Cualquier miembro mueve el reloj de todos.
//
// Los cambios llegan por Realtime (`postgres_changes` sobre la fila de `rooms`)
// si está QtWebSockets (`qt6-websockets`); si no, o mientras se reconecta, se
// consulta la fila cada 2 segundos.
Item {
  id: root

  required property var nube
  property string idioma: "en"

  function t(clave, valores) { return Textos.t(idioma, clave, valores) }

  signal estadoRecibido(var estado)
  signal aviso(string titulo, string cuerpo)
  // Cambió la sala en la que se está (para guardarla).
  signal cambio()

  property string salaId: ""
  property string codigo: ""
  // Ya es miembro: se puede subir el reloj.
  property bool unida: false
  property bool enVivo: false
  property bool soporteRealtime: true
  readonly property string link: codigo ? Supabase.URL_WEB + "/invitacion/" + codigo : ""

  // Para no aplicar el eco de lo propio ni una consulta que salió antes de subir.
  property string ultimoActualizadoEn: ""
  property int version: 0
  property bool subiendo: false
  property var porSubir: null

  // ---- Entrar y salir

  function unirse(texto) {
    var destino = Model.parsearSala(texto)
    if (!destino) return root.aviso("Doro", t("aviso.salaLinkInvalido"))
    if (!nube.configurada) return root.aviso("Doro", t("aviso.sinConexionDoro"))
    if (destino.salaId) return entrar(destino.salaId, "")

    nube.pedirConSesion("POST", "/rest/v1/rpc/join_room", { p_code: destino.codigo }, null, true, function(estado, datos) {
      if (estado === 200 && Model.esUuid(datos)) return entrar(datos, destino.codigo)
      root.aviso(t("aviso.noSePudoEntrarSala"), t(estado === 0 ? "aviso.sinConexion" : "aviso.invitacionVencida"))
    })
  }

  function crear(estadoInicial) {
    if (!nube.configurada) return root.aviso("Doro", t("aviso.sinConexionDoro"))
    nube.pedirConSesion("POST", "/rest/v1/rpc/create_room",
      { p_name: "Sala de estudio", p_is_public: false, p_expires_minutes: null }, null, true, function(estado, datos) {
        var fila = Array.isArray(datos) ? datos[0] : null
        if (estado !== 200 || !fila || !Model.esUuid(fila.room_id)) {
          root.aviso(t("aviso.noSePudoCrearSala"), t(estado === 0 ? "aviso.sinConexion" : "aviso.salaRechazada"))
          return
        }
        cerrarRealtime()
        salaId = fila.room_id
        codigo = fila.invite_code || ""
        unida = true
        root.cambio()
        // Se siembra con el reloj de quien crea, como la web.
        subir(estadoInicial)
        abrirRealtime()
        copiarLink()
        root.aviso(t("aviso.salaCreada"), t("aviso.linkCopiado"))
      })
  }

  // También al volver a abrir el shell, con la sala guardada.
  function entrar(id, codigoConocido) {
    if (id !== salaId) salir()
    salaId = id
    codigo = codigoConocido || ""
    root.cambio()
    conectar()
  }

  function salir() {
    cerrarRealtime()
    salaId = ""
    codigo = ""
    unida = false
    ultimoActualizadoEn = ""
    porSubir = null
    root.cambio()
  }

  // La membresía (`join_room_by_id`, idempotente), el estado actual y el canal.
  function conectar() {
    if (!salaId || unida || !nube.preparada) return
    var id = salaId
    nube.pedirConSesion("POST", "/rest/v1/rpc/join_room_by_id", { p_room_id: id }, null, true, function(estado) {
      if (id !== salaId) return
      if (estado === 200 || estado === 204) {
        unida = true
        traerEstado()
        if (!codigo) traerCodigo()
        abrirRealtime()
      } else if (estado === 0 || estado >= 500) {
        reintento.restart()
      } else {
        root.aviso("Doro", t("aviso.salaNoExiste"))
        salir()
      }
    })
  }

  Connections {
    target: root.nube
    function onPreparadaChanged() { if (root.nube.preparada) root.conectar() }
    // Realtime corta el canal cuando vence el token: se le pasa el nuevo.
    function onSesionChanged() {
      if (root.enVivo && root.nube.sesion)
        root.enviar({ topic: root.tema(), event: "access_token", payload: { access_token: root.nube.sesion.access_token } })
    }
  }

  function traerCodigo() {
    var id = salaId
    nube.pedirConSesion("GET", "/rest/v1/room_invites?select=code&order=created_at.desc&limit=1&room_id=eq." + id,
      null, null, false, function(estado, datos) {
        if (id === salaId && estado === 200 && Array.isArray(datos) && datos[0]) {
          codigo = datos[0].code
          root.cambio()
        }
      })
  }

  function copiarLink() {
    if (link) Quickshell.execDetached(["wl-copy", link])
  }

  // ---- El reloj

  function subir(estado) {
    if (!unida) return
    version++
    ultimoActualizadoEn = estado.actualizadoEn
    if (subiendo) {
      porSubir = estado
      return
    }
    subiendo = true
    var id = salaId
    nube.pedirConSesion("POST", "/rest/v1/rpc/update_room_sync", { p_room_id: id, p_timer_state: estado }, null, false,
      function(codigoHttp) {
        subiendo = false
        if (codigoHttp >= 300 || codigoHttp === 0) console.warn("Doro: update_room_sync respondió", codigoHttp)
        var siguiente = porSubir
        porSubir = null
        if (siguiente && id === salaId) subir(siguiente)
      })
  }

  function traerEstado() {
    if (!unida || subiendo) return
    var id = salaId
    var desde = version
    nube.pedirConSesion("GET", "/rest/v1/rooms?select=timer_state&id=eq." + id, null, null, false, function(estado, datos) {
      if (estado === 200 && Array.isArray(datos) && datos[0] && id === salaId && desde === version && !subiendo)
        recibir(datos[0].timer_state)
    })
  }

  function recibir(estado) {
    if (!Model.esEstadoReloj(estado)) return
    if (estado.actualizadoEn && estado.actualizadoEn === ultimoActualizadoEn) return
    ultimoActualizadoEn = estado.actualizadoEn || ""
    root.estadoRecibido(estado)
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.unida && !root.enVivo
    onTriggered: root.traerEstado()
  }

  Timer {
    id: reintento
    interval: 15000
    onTriggered: root.conectar()
  }

  // ---- Realtime (protocolo de Phoenix, como supabase-js)

  property var socket: null
  property int ref: 0
  property string refUnion: ""

  function tema() { return "realtime:realtime-room-" + salaId }

  function enviar(mensaje) {
    if (!socket || socket.status !== 1) return
    ref++
    mensaje.ref = String(ref)
    socket.sendTextMessage(JSON.stringify(mensaje))
  }

  function abrirRealtime() {
    cerrarRealtime()
    if (!salaId || !soporteRealtime) return
    var nuevo = null
    try {
      nuevo = Qt.createQmlObject("import QtWebSockets; WebSocket {}", root, "DoroRealtime")
    } catch (e) {
      // Sin qt6-websockets: quedan las consultas cada 2 segundos.
      soporteRealtime = false
      return
    }
    socket = nuevo
    nube.asegurarSesion(false, function(ok) {
      if (socket !== nuevo) return
      if (!ok) return reconexion.restart()
      nuevo.textMessageReceived.connect(function(texto) { if (socket === nuevo) root.recibirMensaje(texto) })
      nuevo.statusChanged.connect(function(estado) {
        if (socket !== nuevo) return
        // 1 Open, 3 Closed, 4 Error (WebSocket.Status)
        if (estado === 1) root.unirseCanal()
        else if (estado >= 3) {
          root.enVivo = false
          reconexion.restart()
        }
      })
      nuevo.url = nube.conf.url.replace(/^http/, "ws") + "/realtime/v1/websocket?apikey=" +
        encodeURIComponent(nube.conf.anonKey) + "&vsn=1.0.0"
      nuevo.active = true
    })
  }

  function cerrarRealtime() {
    enVivo = false
    reconexion.stop()
    if (!socket) return
    var viejo = socket
    socket = null
    viejo.active = false
    viejo.destroy()
  }

  function unirseCanal() {
    enviar({
      topic: tema(),
      event: "phx_join",
      payload: {
        config: {
          broadcast: { ack: false, self: false },
          presence: { key: "" },
          postgres_changes: [{ event: "UPDATE", schema: "public", table: "rooms", filter: "id=eq." + salaId }],
          private: false
        },
        access_token: nube.sesion ? nube.sesion.access_token : nube.conf.anonKey
      }
    })
    refUnion = String(ref)
  }

  function recibirMensaje(texto) {
    var mensaje
    try {
      mensaje = JSON.parse(texto)
    } catch (e) {
      return
    }
    if (mensaje.topic !== tema()) return
    var payload = mensaje.payload || {}

    if (mensaje.event === "phx_reply" && mensaje.ref === refUnion) {
      if (payload.status === "ok") {
        enVivo = true
        // Lo que haya cambiado mientras se conectaba.
        traerEstado()
      } else {
        console.warn("Doro: Realtime rechazó el canal", JSON.stringify(payload.response))
        enVivo = false
        reconexion.restart()
      }
    } else if (mensaje.event === "postgres_changes") {
      var fila = payload.data ? payload.data.record : null
      if (fila && fila.timer_state) recibir(fila.timer_state)
    } else if (mensaje.event === "phx_error" || mensaje.event === "phx_close") {
      enVivo = false
      reconexion.restart()
    }
  }

  Timer {
    id: reconexion
    interval: 5000
    onTriggered: if (root.unida && !root.enVivo) root.abrirRealtime()
  }

  Timer {
    // El latido de Phoenix: sin él, el servidor corta a los 60 segundos.
    interval: 25000
    repeat: true
    running: root.enVivo
    onTriggered: root.enviar({ topic: "phoenix", event: "heartbeat", payload: {} })
  }

  Timer {
    // Refresca el token antes de que venza (no pide nada si todavía sirve).
    interval: 30000
    repeat: true
    running: root.unida
    onTriggered: root.nube.asegurarSesion(false, function() {})
  }
}
