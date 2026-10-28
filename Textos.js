.pragma library

// Los textos que ve la gente, en inglés y español. El código queda en español
// (como la web); lo visible sale de acá con `t(idioma, clave, valores)`.
//
// El idioma: el ajuste `language` del widget (`omarchy bar set doro.pomodoro
// language es`) o, sin ajuste, el del sistema: español si `LANG` empieza con
// `es`, inglés en cualquier otro caso.

var IDIOMAS = ["en", "es"]

var TEXTOS = {
  en: {
    "modo.pomodoro": "Pomodoro",
    "modo.shortBreak": "Short break",
    "modo.longBreak": "Long break",
    "modo.stopwatch": "Stopwatch",

    "sonido.rain": "Rain",
    "sonido.fire": "Campfire",
    "sonido.ocean": "Ocean",
    "sonido.thunder": "Thunder",
    "sonido.people": "People",
    "sonido.traffic": "Traffic",
    "sonido.train": "Train",
    "sonido.keyboard": "Keyboard",
    "sonido.birds": "Birds",
    "sonido.brown_noise": "Brown noise",
    "sonido.jazz": "Jazz",
    "sonido.underwater": "Underwater",

    "aviso.pomodoro.titulo": "Pomodoro finished",
    "aviso.pomodoro.cuerpo": "Take a break.",
    "aviso.descanso.titulo": "Break finished",
    "aviso.descanso.cuerpo": "Back to focus.",

    "barra.enPausa": "paused",
    "barra.enSala": "in a room",

    "panel.volverPomodoro": "Back to pomodoro",
    "panel.pasarCronometro": "Switch to stopwatch",
    "panel.salaCompartida": "Shared room",
    "panel.estudiarConOtros": "Study with others",
    "panel.sonidos": "Sounds",
    "panel.reiniciar": "Reset",
    "panel.tiempos": "Times",
    "panel.minutoMenos": "{nombre}: one minute less",
    "panel.minutoMas": "{nombre}: one minute more",
    "panel.min": "min",
    "panel.descansoSolo": "Start breaks automatically",
    "panel.pausarTodo": "Pause all",
    "panel.reanudar": "Resume",
    "panel.apagar": "Turn off {nombre}",
    "panel.verTodos": "Show all {n}",
    "panel.idioma": "Language",

    "sala.ayuda": "Paste an invite link or code, or create a room and share its link.",
    "sala.conectando": "Connecting to the room…",
    "sala.compartida": "Anyone in the room controls this timer.",
    "sala.cadaDosSegundos": " (Updates every 2 seconds.)",
    "sala.placeholder": "doro.page/invitacion/…",
    "sala.unirse": "Join",
    "sala.crear": "Create a room",
    "sala.nombre": "Room {codigo}",
    "sala.sinCodigo": "Room",
    "sala.copiarLink": "Copy the invite link",
    "sala.salir": "Leave the room",

    "cuenta.vaAlDashboard": "Your pomodoros go to the dashboard",
    "cuenta.resumen": "Today {hoy} min · {racha}-day streak",
    "cuenta.verDashboard": "Open the dashboard",
    "cuenta.conTuCuenta": "Signed in",
    "cuenta.entrarCon": "Sign in with",
    "cuenta.entrarConProveedor": "Sign in with {proveedor}",
    "cuenta.salir": "Sign out",

    "aviso.salaLinkInvalido": "That doesn't look like a room link or code.",
    "aviso.sinConexionDoro": "The connection to doro.page isn't set up.",
    "aviso.noSePudoEntrarSala": "Couldn't join the room",
    "aviso.sinConexion": "No connection.",
    "aviso.invitacionVencida": "The invite doesn't exist or has expired.",
    "aviso.noSePudoCrearSala": "Couldn't create the room",
    "aviso.salaRechazada": "Supabase rejected it.",
    "aviso.salaCreada": "Room created",
    "aviso.linkCopiado": "Invite link copied: share it so others can join.",
    "aviso.salaNoExiste": "The room no longer exists.",
    "aviso.sesionCerrada": "You were signed out. Sign in again from the panel.",
    "aviso.noSePudoEntrar": "Couldn't sign in",
    "aviso.sesionNoReconocida": "Supabase didn't recognize the session.",
    "aviso.entraste": "Signed in as {nombre}.",
    "aviso.tuCuenta": "your account",
    "aviso.fusionFallida": "Couldn't move your anonymous pomodoros to your account.",
    "aviso.retornoInvalido": "That isn't a Doro sign-in link.",
    "aviso.faltanTokens": "The sign-in came back without a session.",
    "aviso.proveedorRechazo": "The provider didn't complete the sign-in.",
    "aviso.sinAzar": "Couldn't prepare a secure sign-in."
  },

  es: {
    "modo.pomodoro": "Pomodoro",
    "modo.shortBreak": "Descanso corto",
    "modo.longBreak": "Descanso largo",
    "modo.stopwatch": "Cronómetro",

    "sonido.rain": "Lluvia",
    "sonido.fire": "Fogata",
    "sonido.ocean": "Océano",
    "sonido.thunder": "Truenos",
    "sonido.people": "Personas",
    "sonido.traffic": "Tráfico",
    "sonido.train": "Tren",
    "sonido.keyboard": "Teclado",
    "sonido.birds": "Pájaros",
    "sonido.brown_noise": "Ruido marrón",
    "sonido.jazz": "Jazz",
    "sonido.underwater": "Subacuático",

    "aviso.pomodoro.titulo": "Terminó el pomodoro",
    "aviso.pomodoro.cuerpo": "Tomate un descanso.",
    "aviso.descanso.titulo": "Terminó el descanso",
    "aviso.descanso.cuerpo": "A enfocarse de nuevo.",

    "barra.enPausa": "en pausa",
    "barra.enSala": "en sala",

    "panel.volverPomodoro": "Volver al pomodoro",
    "panel.pasarCronometro": "Pasar a cronómetro",
    "panel.salaCompartida": "Sala compartida",
    "panel.estudiarConOtros": "Estudiar con otros",
    "panel.sonidos": "Sonidos",
    "panel.reiniciar": "Reiniciar",
    "panel.tiempos": "Tiempos",
    "panel.minutoMenos": "{nombre}: un minuto menos",
    "panel.minutoMas": "{nombre}: un minuto más",
    "panel.min": "min",
    "panel.descansoSolo": "Arrancar el descanso solo",
    "panel.pausarTodo": "Pausar todo",
    "panel.reanudar": "Reanudar",
    "panel.apagar": "Apagar {nombre}",
    "panel.verTodos": "Ver los {n}",
    "panel.idioma": "Idioma",

    "sala.ayuda": "Pegá el link o el código de una invitación, o creá una sala y compartí su link.",
    "sala.conectando": "Conectando con la sala…",
    "sala.compartida": "Cualquiera en la sala mueve este reloj.",
    "sala.cadaDosSegundos": " (Se actualiza cada 2 segundos.)",
    "sala.placeholder": "doro.page/invitacion/…",
    "sala.unirse": "Unirse",
    "sala.crear": "Crear una sala",
    "sala.nombre": "Sala {codigo}",
    "sala.sinCodigo": "Sala",
    "sala.copiarLink": "Copiar el link de invitación",
    "sala.salir": "Salir de la sala",

    "cuenta.vaAlDashboard": "Tus pomodoros van al dashboard",
    "cuenta.resumen": "Hoy {hoy} min · racha de {racha} {dias}",
    "cuenta.verDashboard": "Ver el dashboard",
    "cuenta.conTuCuenta": "Con tu cuenta",
    "cuenta.entrarCon": "Entrar con",
    "cuenta.entrarConProveedor": "Entrar con {proveedor}",
    "cuenta.salir": "Salir",

    "aviso.salaLinkInvalido": "Eso no parece un link ni un código de sala.",
    "aviso.sinConexionDoro": "Falta configurar la conexión con doro.page.",
    "aviso.noSePudoEntrarSala": "No se pudo entrar a la sala",
    "aviso.sinConexion": "Sin conexión.",
    "aviso.invitacionVencida": "La invitación no existe o venció.",
    "aviso.noSePudoCrearSala": "No se pudo crear la sala",
    "aviso.salaRechazada": "Supabase la rechazó.",
    "aviso.salaCreada": "Sala creada",
    "aviso.linkCopiado": "Copiaste el link: compartilo para que se unan.",
    "aviso.salaNoExiste": "La sala ya no existe.",
    "aviso.sesionCerrada": "Se cerró tu sesión. Volvé a entrar desde el panel.",
    "aviso.noSePudoEntrar": "No se pudo entrar",
    "aviso.sesionNoReconocida": "Supabase no reconoció la sesión.",
    "aviso.entraste": "Entraste como {nombre}.",
    "aviso.tuCuenta": "tu cuenta",
    "aviso.fusionFallida": "No se pudieron pasar los pomodoros anónimos a tu cuenta.",
    "aviso.retornoInvalido": "No es una vuelta de inicio de sesión de Doro.",
    "aviso.faltanTokens": "El inicio de sesión volvió sin sesión.",
    "aviso.proveedorRechazo": "El proveedor no completó el inicio de sesión.",
    "aviso.sinAzar": "No se pudo preparar un inicio de sesión seguro."
  }
}

/** "en" o "es"; cualquier otra cosa cae al inglés. */
function idiomaValido(idioma) {
  return IDIOMAS.indexOf(idioma) !== -1 ? idioma : "en"
}

/**
 * El idioma a usar: el del ajuste si es uno conocido; si no, el del sistema
 * (`LC_ALL`, `LC_MESSAGES` o `LANG`, el primero que haya).
 */
function idiomaElegido(ajuste, locale) {
  if (IDIOMAS.indexOf(ajuste) !== -1) return ajuste
  return /^es([_.@-]|$)/i.test(String(locale || "")) ? "es" : "en"
}

/** El texto de `clave` con `{valores}` reemplazados; si falta, el inglés o la clave. */
function t(idioma, clave, valores) {
  var tabla = TEXTOS[idiomaValido(idioma)]
  var texto = tabla[clave]
  if (texto === undefined) texto = TEXTOS.en[clave]
  if (texto === undefined) return clave
  for (var nombre in valores || {}) texto = texto.split("{" + nombre + "}").join(String(valores[nombre]))
  return texto
}

/** El resumen del día con el plural de la racha («1 día», «2 días»). */
function resumen(idioma, hoy, racha) {
  return t(idioma, "cuenta.resumen", { hoy: hoy, racha: racha, dias: racha === 1 ? "día" : "días" })
}

/** Título y cuerpo del aviso de fin de fase. */
function aviso(idioma, modoTerminado) {
  var clave = modoTerminado === "pomodoro" ? "aviso.pomodoro" : "aviso.descanso"
  return { titulo: t(idioma, clave + ".titulo"), cuerpo: t(idioma, clave + ".cuerpo") }
}
