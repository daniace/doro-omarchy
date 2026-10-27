.pragma library

// Lógica pura de la conexión con Supabase (la misma base que doro.page), sin QML,
// para poder probarla aparte. Lo que tiene efectos (pedidos, archivos) vive en
// `Nube.qml`.
//
// Habla con la API REST de Supabase a mano (`/auth/v1`, `/rest/v1`), porque QML
// no tiene supabase-js; el contrato es el de la web:
//   - un pomodoro terminado es una fila en `study_sessions` y el trigger
//     `trg_update_stats` actualiza `user_stats`;
//   - la sesión es anónima hasta que se entra con Google, GitHub o Discord.

// El proyecto de doro.page. La clave anon es pública (viaja en el bundle de la
// web). Los reemplazan, en orden: el `.env` de la carpeta del plugin
// (`DORO_SUPABASE_URL`, `DORO_SUPABASE_ANON_KEY`) y `~/.config/doro/supabase.json`
// (`{ "url", "anonKey" }`).
var URL_PROYECTO = "https://lqzkimyxgpklrfhiftnr.supabase.co"
var ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxxemtpbXl4Z3BrbHJmaGlmdG5yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjEyNDgxMjAsImV4cCI6MjA3NjgyNDEyMH0.jUR96zqZq4hkDEWllOr6s_fPd1sOO-9PHxmDcR9jj9o"

/** Las variables de un `.env` (`CLAVE=valor`, con o sin comillas; `#` comenta). */
function leerEnv(texto) {
  var variables = {}
  var lineas = String(texto || "").split("\n")
  for (var i = 0; i < lineas.length; i++) {
    var linea = lineas[i].trim()
    if (!linea || linea[0] === "#") continue
    var coincidencia = linea.match(/^(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/)
    if (!coincidencia) continue
    var valor = coincidencia[2].trim()
    if (/^(["']).*\1$/.test(valor)) valor = valor.slice(1, -1)
    else valor = valor.replace(/\s+#.*$/, "")
    variables[coincidencia[1]] = valor
  }
  return variables
}

/** `{ url, anonKey }` del `.env` del plugin, o las constantes si no los trae. */
function configuracionEnv(texto) {
  var variables = leerEnv(texto)
  // Los `<…>` del `.env.example` sin completar no cuentan.
  var completo = function(valor) { return valor && valor.indexOf("<") === -1 ? valor : "" }
  return configuracion(JSON.stringify({
    url: completo(variables.DORO_SUPABASE_URL),
    anonKey: completo(variables.DORO_SUPABASE_ANON_KEY)
  }))
}

var URL_WEB = "https://doro.page"
var REDIRECCION = "doro://auth"
var PROVEEDORES = ["google", "github", "discord"]

// Se refresca un minuto antes de que venza, como supabase-js.
var MARGEN_VENCIMIENTO_MS = 60 * 1000

/**
 * `{ url, anonKey }` de `supabase.json`; lo que falte sale de `base` (lo del
 * `.env`) o de las constantes.
 */
function configuracion(texto, base) {
  var datos = {}
  try {
    datos = JSON.parse(texto || "{}") || {}
  } catch (e) {
    datos = {}
  }
  var respaldo = base || { url: URL_PROYECTO, anonKey: ANON_KEY }
  var url = typeof datos.url === "string" && datos.url ? datos.url : respaldo.url
  var anonKey = typeof datos.anonKey === "string" && datos.anonKey ? datos.anonKey : respaldo.anonKey
  return { url: url.replace(/\/+$/, ""), anonKey: anonKey }
}

function esProveedor(proveedor) {
  return PROVEEDORES.indexOf(proveedor) !== -1
}

/** Entrar con OAuth (flujo implícito: los tokens vuelven en el fragmento de `doro://auth`). */
function urlEntrar(base, proveedor) {
  return base + "/auth/v1/authorize?provider=" + encodeURIComponent(proveedor) +
    "&redirect_to=" + encodeURIComponent(REDIRECCION)
}

/** Vincular una cuenta a la sesión anónima (`linkIdentity`): devuelve `{ url }` en JSON. */
function urlVincular(base, proveedor) {
  return base + "/auth/v1/user/identities/authorize?provider=" + encodeURIComponent(proveedor) +
    "&redirect_to=" + encodeURIComponent(REDIRECCION) + "&skip_http_redirect=true"
}

function parametros(texto) {
  var resultado = {}
  if (!texto) return resultado
  var partes = texto.split("&")
  for (var i = 0; i < partes.length; i++) {
    if (!partes[i]) continue
    var igual = partes[i].indexOf("=")
    var clave = igual === -1 ? partes[i] : partes[i].slice(0, igual)
    var valor = igual === -1 ? "" : partes[i].slice(igual + 1)
    try {
      resultado[decodeURIComponent(clave)] = decodeURIComponent(valor.replace(/\+/g, " "))
    } catch (e) {
      resultado[clave] = valor
    }
  }
  return resultado
}

/**
 * Lee la vuelta del OAuth (`doro://auth?…#…`). Devuelve
 * `{ tokens: { access_token, refresh_token, expires_at } }` o
 * `{ error, codigo }`; Supabase pone los errores en la query o en el fragmento.
 */
function parsearRetorno(url, ahora) {
  if (typeof url !== "string" || url.indexOf(REDIRECCION) !== 0)
    return { error: "No es una vuelta de Doro", codigo: "" }
  var resto = url.slice(REDIRECCION.length)
  var numeral = resto.indexOf("#")
  var query = numeral === -1 ? resto : resto.slice(0, numeral)
  var fragmento = numeral === -1 ? "" : resto.slice(numeral + 1)
  var datos = Object.assign(parametros(query.replace(/^[/?]+/, "")), parametros(fragmento))

  if (datos.error || datos.error_code)
    return { error: datos.error_description || datos.error || "Error al entrar", codigo: datos.error_code || "" }
  if (!datos.access_token || !datos.refresh_token)
    return { error: "Faltan los tokens", codigo: "" }
  return { tokens: sesionDesdeRespuesta(datos, ahora) }
}

/** Normaliza la sesión de `/signup`, `/token` o la vuelta del OAuth. */
function sesionDesdeRespuesta(datos, ahora) {
  var expiraEn = Number(datos.expires_at) * 1000
  if (!isFinite(expiraEn) || expiraEn <= 0) expiraEn = ahora + (Number(datos.expires_in) || 3600) * 1000
  return {
    access_token: datos.access_token,
    refresh_token: datos.refresh_token,
    expires_at: expiraEn,
    usuario: datos.user ? usuarioDesde(datos.user) : null
  }
}

/** Lo que muestra el panel del usuario de `/auth/v1/user`. */
function usuarioDesde(user) {
  if (!user || !user.id) return null
  var meta = user.user_metadata || {}
  return {
    id: user.id,
    anonimo: !!user.is_anonymous,
    nombre: meta.full_name || meta.name || meta.user_name || meta.preferred_username || user.email || ""
  }
}

/** Sesión guardada en `sesion.json`, o null si no sirve. */
function sesionGuardada(texto) {
  var datos
  try {
    datos = JSON.parse(texto || "null")
  } catch (e) {
    return null
  }
  if (!datos || typeof datos.access_token !== "string" || typeof datos.refresh_token !== "string") return null
  return {
    access_token: datos.access_token,
    refresh_token: datos.refresh_token,
    expires_at: Number(datos.expires_at) || 0,
    usuario: datos.usuario && datos.usuario.id ? datos.usuario : null
  }
}

function sesionVencida(sesion, ahora) {
  return !sesion || sesion.expires_at - MARGEN_VENCIMIENTO_MS <= ahora
}

// ---- Pomodoros sin subir: se encolan con su hora real, así lo hecho sin
//      conexión cae en el día correcto del dashboard.

function pendientesGuardados(texto) {
  var datos
  try {
    datos = JSON.parse(texto || "[]")
  } catch (e) {
    return []
  }
  if (!Array.isArray(datos)) return []
  return datos.filter(function(p) {
    return p && Number(p.duration_minutes) > 0 && typeof p.created_at === "string"
  })
}

function agregarPendiente(pendientes, minutos, fecha) {
  return pendientes.concat([{ duration_minutes: Math.round(minutos), created_at: fecha.toISOString() }])
}

/** Las filas de `study_sessions` de los pendientes para un usuario. */
function filasSesiones(pendientes, userId) {
  return pendientes.map(function(p) {
    return { user_id: userId, duration_minutes: p.duration_minutes, created_at: p.created_at }
  })
}

/** Saca de la cola los que ya se subieron (los primeros `subidos`). */
function sacarPendientes(pendientes, subidos) {
  return pendientes.slice(subidos)
}

// ---- El resumen del panel.

/** `AAAA-MM-DD` en hora local, como `stat_date` de `get_dashboard_aggregates`. */
function fechaLocal(fecha) {
  var mes = fecha.getMonth() + 1
  var dia = fecha.getDate()
  return fecha.getFullYear() + "-" + (mes < 10 ? "0" : "") + mes + "-" + (dia < 10 ? "0" : "") + dia
}

/**
 * `{ hoy, racha }` desde `user_stats` y `get_dashboard_aggregates`. El trigger
 * solo toca la racha al guardar, así que si el último día de estudio quedó antes
 * de ayer, ya se cortó.
 */
function resumen(stats, agregados, fecha) {
  var hoy = 0
  var dias = agregados && Array.isArray(agregados.daily) ? agregados.daily : []
  var clave = fechaLocal(fecha)
  for (var i = 0; i < dias.length; i++)
    if (dias[i].stat_date === clave) hoy = Number(dias[i].total_minutes) || 0

  var racha = stats ? Number(stats.current_streak) || 0 : 0
  var ayer = fechaLocal(new Date(fecha.getFullYear(), fecha.getMonth(), fecha.getDate() - 1))
  if (stats && typeof stats.last_study_date === "string" && stats.last_study_date < ayer) racha = 0
  return { hoy: hoy, racha: racha }
}
