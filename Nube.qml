import QtQuick
import Quickshell
import Quickshell.Io
import "Supabase.js" as Supabase
import "Textos.js" as Textos

// La conexión con doro.page: la sesión, los pomodoros que van al dashboard y el
// resumen del panel. Vive dentro del servicio, uno por sesión del shell.
//
// Como la web (`asegurarSesion`), la sesión anónima se crea recién al guardar el
// primer pomodoro; entrar con una cuenta la vincula y conserva lo hecho.
Item {
  id: root

  required property string carpetaEstado
  property string idioma: "en"

  function t(clave, valores) { return Textos.t(idioma, clave, valores) }

  signal aviso(string titulo, string cuerpo)

  property var conf: Supabase.configuracion("")
  readonly property bool configurada: conf.url !== "" && conf.anonKey !== ""

  property var sesion: null
  readonly property var usuario: sesion ? sesion.usuario : null
  property var pendientes: []
  property var resumen: null

  // La sesión, los pendientes y la configuración se leen cuando la carpeta existe.
  // Nada pide sesión antes de `preparada`: si no, se crearía una anónima nueva
  // antes de leer la guardada.
  property bool listo: false
  property bool confLeida: false
  property bool sesionLeida: false
  readonly property bool preparada: confLeida && sesionLeida
  onPreparadaChanged: if (preparada) alCambiarSesion()
  property bool subiendo: false
  property bool pidiendoSesion: false
  property var esperandoSesion: []

  // Entrar a una cuenta que ya existía desde una sesión anónima: se guarda el
  // token del anónimo para que `sumar-anonimo` pase lo hecho a la cuenta.
  property string proveedorEnCurso: ""
  property string tokenAnonimoPorFusionar: ""

  function cargar() {
    listo = true
    permisos.running = true
  }

  // ---- Pedidos

  function pedir(metodo, ruta, cuerpo, token, encabezados, cb) {
    var xhr = new XMLHttpRequest()
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      var datos = null
      try {
        datos = xhr.responseText ? JSON.parse(xhr.responseText) : null
      } catch (e) {
        datos = null
      }
      cb(xhr.status, datos)
    }
    xhr.open(metodo, conf.url + ruta)
    xhr.setRequestHeader("apikey", conf.anonKey)
    xhr.setRequestHeader("Authorization", "Bearer " + (token || conf.anonKey))
    for (var clave in encabezados || {}) xhr.setRequestHeader(clave, encabezados[clave])
    if (cuerpo === undefined || cuerpo === null) {
      xhr.send()
    } else {
      xhr.setRequestHeader("Content-Type", "application/json")
      xhr.send(JSON.stringify(cuerpo))
    }
  }

  // Con la sesión al día; ante un 401 la refresca y reintenta una vez.
  function pedirConSesion(metodo, ruta, cuerpo, encabezados, crear, cb) {
    asegurarSesion(crear, function(ok) {
      if (!ok) return cb(0, null)
      pedir(metodo, ruta, cuerpo, sesion.access_token, encabezados, function(estado, datos) {
        if (estado !== 401) return cb(estado, datos)
        sesion.expires_at = 0
        asegurarSesion(false, function(ok2) {
          if (!ok2) return cb(401, datos)
          pedir(metodo, ruta, cuerpo, sesion.access_token, encabezados, cb)
        })
      })
    })
  }

  // ---- Sesión

  // `crear`: sin sesión, entra como anónimo (solo antes de escribir algo).
  function asegurarSesion(crear, cb) {
    if (!preparada || !configurada) return cb(false)
    if (sesion && !Supabase.sesionVencida(sesion, Date.now())) return cb(true)
    if (!sesion && !crear) return cb(false)

    esperandoSesion = esperandoSesion.concat([cb])
    if (pidiendoSesion) return
    pidiendoSesion = true

    var terminar = function(ok) {
      var esperando = esperandoSesion
      esperandoSesion = []
      pidiendoSesion = false
      for (var i = 0; i < esperando.length; i++) esperando[i](ok)
    }

    if (sesion) {
      pedir("POST", "/auth/v1/token?grant_type=refresh_token", { refresh_token: sesion.refresh_token }, null, null,
        function(estado, datos) {
          if (estado === 200 && datos && datos.access_token) {
            establecerSesion(Supabase.sesionDesdeRespuesta(datos, Date.now()))
            return terminar(true)
          }
          // Sin red se conserva la sesión; un refresh rechazado la cierra.
          if (estado >= 400 && estado < 500) {
            var eraCuenta = usuario && !usuario.anonimo
            establecerSesion(null)
            if (eraCuenta) root.aviso("Doro", t("aviso.sesionCerrada"))
          }
          terminar(false)
        })
      return
    }

    pedir("POST", "/auth/v1/signup", {}, null, null, function(estado, datos) {
      if (estado === 200 && datos && datos.access_token) {
        establecerSesion(Supabase.sesionDesdeRespuesta(datos, Date.now()))
        return terminar(true)
      }
      console.warn("Doro: no se pudo crear la sesión anónima", estado)
      terminar(false)
    })
  }

  function establecerSesion(nueva) {
    sesion = nueva
    resumen = null
    archivoSesion.setText(JSON.stringify(nueva, null, 2) + "\n")
  }

  function entrar(proveedor) {
    if (!configurada || !Supabase.esProveedor(proveedor)) return
    proveedorEnCurso = proveedor
    instalarManejador(function() {
      if (!usuario || !usuario.anonimo) {
        tokenAnonimoPorFusionar = ""
        return abrir(Supabase.urlEntrar(conf.url, proveedor))
      }
      // Anónimo: se le vincula la cuenta y conserva su id, como `linkIdentity`.
      pedirConSesion("GET", Supabase.urlVincular("", proveedor), null, null, false, function(estado, datos) {
        if (estado === 200 && datos && datos.url) abrir(datos.url)
        else abrir(Supabase.urlEntrar(conf.url, proveedor))
      })
    })
  }

  // La vuelta del navegador por `doro://auth` (IPC `authCallback`).
  function recibirRetorno(url) {
    var retorno = Supabase.parsearRetorno(url, Date.now())
    if (!retorno.tokens) {
      // La cuenta ya existía: se entra a ella y después se le suma el anónimo.
      if (retorno.codigo === "identity_already_exists" && usuario && usuario.anonimo && proveedorEnCurso) {
        tokenAnonimoPorFusionar = sesion.access_token
        abrir(Supabase.urlEntrar(conf.url, proveedorEnCurso))
        return
      }
      var motivos = { retorno_invalido: "aviso.retornoInvalido", faltan_tokens: "aviso.faltanTokens" }
      root.aviso(t("aviso.noSePudoEntrar"), motivos[retorno.codigo] ? t(motivos[retorno.codigo]) : retorno.error)
      return
    }

    var tokens = retorno.tokens
    pedir("GET", "/auth/v1/user", null, tokens.access_token, null, function(estado, datos) {
      var nuevoUsuario = estado === 200 ? Supabase.usuarioDesde(datos) : null
      if (!nuevoUsuario) {
        root.aviso(t("aviso.noSePudoEntrar"), t("aviso.sesionNoReconocida"))
        return
      }
      tokens.usuario = nuevoUsuario
      establecerSesion(tokens)
      proveedorEnCurso = ""
      root.aviso("Doro", t("aviso.entraste", { nombre: nuevoUsuario.nombre || t("aviso.tuCuenta") }))

      var tokenAnonimo = tokenAnonimoPorFusionar
      tokenAnonimoPorFusionar = ""
      if (tokenAnonimo && !nuevoUsuario.anonimo) fusionarAnonimo(tokenAnonimo)
      else alCambiarSesion()
    })
  }

  function fusionarAnonimo(tokenAnonimo) {
    pedirConSesion("POST", "/functions/v1/sumar-anonimo", { token_anonimo: tokenAnonimo }, null, false,
      function(estado) {
        if (estado !== 200) {
          console.warn("Doro: sumar-anonimo respondió", estado)
          root.aviso("Doro", t("aviso.fusionFallida"))
        }
        alCambiarSesion()
      })
  }

  function salir() {
    establecerSesion(null)
  }

  function alCambiarSesion() {
    subirPendientes()
    cargarResumen()
  }

  // ---- Pomodoros

  function registrarPomodoro(minutos) {
    if (!(minutos > 0)) return
    guardarPendientes(Supabase.agregarPendiente(pendientes, minutos, new Date()))
    subirPendientes()
  }

  function subirPendientes() {
    if (!preparada || !configurada || subiendo || pendientes.length === 0) return
    subiendo = true
    var lote = pendientes.slice()
    asegurarSesion(true, function(ok) {
      if (!ok) {
        subiendo = false
        return
      }
      pedirConSesion("POST", "/rest/v1/study_sessions", Supabase.filasSesiones(lote, usuario.id),
        { "Prefer": "return=minimal" }, false, function(estado) {
          subiendo = false
          // Sin red o con el servidor caído quedan para después; un rechazo no
          // se arregla reintentando, así que ese lote se descarta.
          if (estado === 0 || estado >= 500 || estado === 401) return
          if (estado >= 300) console.warn("Doro: study_sessions rechazó", lote.length, "pomodoros:", estado)
          guardarPendientes(Supabase.sacarPendientes(pendientes, lote.length))
          cargarResumen()
          subirPendientes()
        })
    })
  }

  function guardarPendientes(nuevos) {
    pendientes = nuevos
    archivoPendientes.setText(JSON.stringify(nuevos, null, 2) + "\n")
  }

  // ---- Resumen del panel (no crea sesión: sin pomodoros no hay nada que mostrar)

  function cargarResumen() {
    if (!sesion) {
      resumen = null
      return
    }
    pedirConSesion("GET", "/rest/v1/user_stats?select=current_streak,last_study_date&user_id=eq." + usuario.id,
      null, null, false, function(estado, stats) {
        if (estado !== 200) return
        pedirConSesion("POST", "/rest/v1/rpc/get_dashboard_aggregates", { p_user_id: usuario.id }, null, false,
          function(estado2, agregados) {
            if (estado2 !== 200) return
            resumen = Supabase.resumen(Array.isArray(stats) ? stats[0] : null, agregados, new Date())
          })
      })
  }

  function abrirDashboard() {
    abrir(Supabase.URL_WEB + "/dashboard")
  }

  function abrir(url) {
    Quickshell.execDetached(["xdg-open", url])
  }

  // ---- Archivos

  // La carpeta guarda tokens: solo para el usuario.
  Process {
    id: permisos
    command: ["chmod", "700", root.carpetaEstado]
  }

  // `doro://auth` vuelve al plugin: un .desktop que pasa la URL por IPC.
  property var alInstalarManejador: null

  function instalarManejador(cb) {
    alInstalarManejador = cb
    manejador.running = true
  }

  Process {
    id: manejador
    command: ["sh", "-c",
      'd="${XDG_DATA_HOME:-$HOME/.local/share}/applications"; mkdir -p "$d" && ' +
      'printf "%s\\n" "[Desktop Entry]" "Type=Application" "Name=Doro (sign-in)" "NoDisplay=true" ' +
      '"Exec=omarchy-shell doro.pomodoro authCallback %u" "MimeType=x-scheme-handler/doro;" > "$d/doro-auth.desktop" && ' +
      'xdg-mime default doro-auth.desktop x-scheme-handler/doro']
    onExited: function(codigo) {
      if (codigo !== 0) console.warn("Doro: no se pudo registrar doro://", codigo)
      var cb = root.alInstalarManejador
      root.alInstalarManejador = null
      if (cb) cb()
    }
  }

  // La conexión: el `.env` del plugin y, encima, `~/.config/doro/supabase.json`.
  property var confEnv: null

  function leerConfiguracion(textoJson) {
    conf = Supabase.configuracion(textoJson, confEnv)
    confLeida = true
  }

  FileView {
    path: root.listo ? Qt.resolvedUrl(".env").toString().replace(/^file:\/\//, "") : ""
    printErrors: false
    onLoaded: { root.confEnv = Supabase.configuracionEnv(text()); archivoConf.path = root.rutaConf }
    onLoadFailed: archivoConf.path = root.rutaConf
  }

  readonly property string rutaConf: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/doro/supabase.json"

  FileView {
    id: archivoConf
    printErrors: false
    onLoaded: root.leerConfiguracion(text())
    onLoadFailed: root.leerConfiguracion("")
  }

  FileView {
    id: archivoSesion
    path: root.listo ? root.carpetaEstado + "/sesion.json" : ""
    atomicWrites: true
    printErrors: false
    onLoaded: if (!root.sesionLeida) { root.sesion = Supabase.sesionGuardada(text()); root.sesionLeida = true }
    onLoadFailed: root.sesionLeida = true
  }

  FileView {
    id: archivoPendientes
    path: root.listo ? root.carpetaEstado + "/pendientes.json" : ""
    atomicWrites: true
    printErrors: false
    onLoaded: { root.pendientes = Supabase.pendientesGuardados(text()); root.subirPendientes() }
  }

  Timer {
    // Lo que no se pudo subir se reintenta cada 5 minutos.
    interval: 5 * 60 * 1000
    repeat: true
    running: root.pendientes.length > 0
    onTriggered: root.subirPendientes()
  }
}
