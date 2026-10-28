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

// ---- PKCE
//
// Entrar es OAuth con PKCE, como supabase-js con `flowType: "pkce"`: `doro://auth`
// vuelve con un `code` de un solo uso que solo se canjea con el verificador que
// quedó en memoria. Así la vuelta no trae tokens (que quedarían en el argv del
// `.desktop`) y una vuelta que no empezó este reloj no sirve de nada.

/** El verificador (RFC 7636): 64 caracteres hex de 32 bytes aleatorios (`/dev/urandom`). */
function verificadorDesde(azar) {
  var hex = String(azar || "").replace(/\s+/g, "").toLowerCase()
  return /^[0-9a-f]{64}$/.test(hex) ? hex : ""
}

/** El `code_challenge` S256: SHA-256 del verificador, en base64url sin relleno. */
function desafio(verificador) {
  var bytes = sha256(bytesAscii(verificador))
  var tabla = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
  var salida = ""
  for (var i = 0; i < bytes.length; i += 3) {
    var n = (bytes[i] << 16) | ((bytes[i + 1] || 0) << 8) | (bytes[i + 2] || 0)
    salida += tabla[(n >> 18) & 63] + tabla[(n >> 12) & 63]
    if (i + 1 < bytes.length) salida += tabla[(n >> 6) & 63]
    if (i + 2 < bytes.length) salida += tabla[n & 63]
  }
  return salida
}

function bytesAscii(texto) {
  var bytes = []
  for (var i = 0; i < texto.length; i++) bytes.push(texto.charCodeAt(i) & 0xff)
  return bytes
}

// QML no trae `crypto.subtle`: SHA-256 (FIPS 180-4) a mano, sobre un array de bytes.
var K_SHA256 = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
]

function sha256(entrada) {
  var bytes = entrada.slice()
  var bits = bytes.length * 8
  bytes.push(0x80)
  while (bytes.length % 64 !== 56) bytes.push(0)
  // Largo en bits, big-endian en 64 bits (los mensajes de acá caben en 32).
  bytes.push(0, 0, 0, 0, (bits >>> 24) & 0xff, (bits >>> 16) & 0xff, (bits >>> 8) & 0xff, bits & 0xff)

  var h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
  var rotar = function(x, n) { return (x >>> n) | (x << (32 - n)) }
  var w = new Array(64)
  for (var bloque = 0; bloque < bytes.length; bloque += 64) {
    for (var i = 0; i < 16; i++) {
      var j = bloque + i * 4
      w[i] = (bytes[j] << 24) | (bytes[j + 1] << 16) | (bytes[j + 2] << 8) | bytes[j + 3]
    }
    for (i = 16; i < 64; i++) {
      var s0 = rotar(w[i - 15], 7) ^ rotar(w[i - 15], 18) ^ (w[i - 15] >>> 3)
      var s1 = rotar(w[i - 2], 17) ^ rotar(w[i - 2], 19) ^ (w[i - 2] >>> 10)
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) | 0
    }
    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7]
    for (i = 0; i < 64; i++) {
      var t1 = (hh + (rotar(e, 6) ^ rotar(e, 11) ^ rotar(e, 25)) + ((e & f) ^ (~e & g)) + K_SHA256[i] + w[i]) | 0
      var t2 = ((rotar(a, 2) ^ rotar(a, 13) ^ rotar(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) | 0
      hh = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0
    }
    h = [(h[0] + a) | 0, (h[1] + b) | 0, (h[2] + c) | 0, (h[3] + d) | 0,
         (h[4] + e) | 0, (h[5] + f) | 0, (h[6] + g) | 0, (h[7] + hh) | 0]
  }

  var salida = []
  for (i = 0; i < 8; i++) salida.push((h[i] >>> 24) & 0xff, (h[i] >>> 16) & 0xff, (h[i] >>> 8) & 0xff, h[i] & 0xff)
  return salida
}

function parametrosPkce(verificador) {
  return "&code_challenge=" + desafio(verificador) + "&code_challenge_method=s256"
}

/** Entrar con OAuth: vuelve a `doro://auth?code=…`. */
function urlEntrar(base, proveedor, verificador) {
  return base + "/auth/v1/authorize?provider=" + encodeURIComponent(proveedor) +
    "&redirect_to=" + encodeURIComponent(REDIRECCION) + parametrosPkce(verificador)
}

/** Vincular una cuenta a la sesión anónima (`linkIdentity`): devuelve `{ url }` en JSON. */
function urlVincular(base, proveedor, verificador) {
  return base + "/auth/v1/user/identities/authorize?provider=" + encodeURIComponent(proveedor) +
    "&redirect_to=" + encodeURIComponent(REDIRECCION) + "&skip_http_redirect=true" + parametrosPkce(verificador)
}

/** El cuerpo de `POST /auth/v1/token?grant_type=pkce`. */
function canjePkce(codigo, verificador) {
  return { auth_code: codigo, code_verifier: verificador }
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
 * Lee la vuelta del OAuth (`doro://auth?code=…`). Devuelve `{ autorizacion }` (el
 * `code` a canjear) o `{ error, codigo }`: `codigo` es el `error_code` de Supabase
 * (que pone los errores en la query o en el fragmento), `retorno_invalido` o
 * `falta_codigo`; `error`, su descripción si la trae (solo para el log: viene de la
 * URL y la puede escribir cualquiera). Tokens sueltos en la URL no se aceptan.
 */
function parsearRetorno(url) {
  if (typeof url !== "string" || url.indexOf(REDIRECCION) !== 0 || !/^($|[/?#])/.test(url.slice(REDIRECCION.length)))
    return { error: "", codigo: "retorno_invalido" }
  var resto = url.slice(REDIRECCION.length)
  var numeral = resto.indexOf("#")
  var query = numeral === -1 ? resto : resto.slice(0, numeral)
  var fragmento = numeral === -1 ? "" : resto.slice(numeral + 1)
  var datos = Object.assign(parametros(query.replace(/^[/?]+/, "")), parametros(fragmento))

  if (datos.error || datos.error_code)
    return { error: datos.error_description || datos.error || "", codigo: datos.error_code || "error" }
  if (!datos.code)
    return { error: "", codigo: "falta_codigo" }
  return { autorizacion: datos.code }
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
  // Al vincular una cuenta a una sesión anónima, el nombre queda en la identidad
  // del proveedor y no en `user_metadata`.
  var identidades = Array.isArray(user.identities) ? user.identities : []
  var nombre = meta.full_name || meta.name || meta.user_name || meta.preferred_username || ""
  for (var i = 0; !nombre && i < identidades.length; i++) {
    var datos = identidades[i].identity_data || {}
    nombre = datos.full_name || datos.name || datos.user_name || datos.preferred_username || ""
  }
  return { id: user.id, anonimo: !!user.is_anonymous, nombre: nombre || user.email || "" }
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
