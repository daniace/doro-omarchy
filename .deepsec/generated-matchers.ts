import { compileDeclarativeMatchers, type DeepsecPlugin } from "deepsec/config";

const specs = [
  {
    "version": 1,
    "slug": "qml-shellipc-command",
    "description": "Quickshell ShellIpc command surface for the doro.pomodoro plugin: the ShellIpc element bound to the plugin id, plus every typed IPC handler (`function name(arg: type): void`) reachable as `omarchy-shell doro.pomodoro <fn>` by any process in the user's session with no caller authentication.",
    "noiseTier": "noisy",
    "filePatterns": [
      "**/*.qml"
    ],
    "requires": {
      "sentinelFiles": [
        "manifest.json"
      ]
    },
    "patterns": [
      {
        "source": "ShellIpc\\s*\\{",
        "label": "Quickshell ShellIpc command target declaration"
      },
      {
        "source": "function\\s+[A-Za-z][A-Za-z0-9_]*\\s*\\([^)]*\\)\\s*:\\s*(?:void|string|int|bool|real)\\b",
        "label": "Typed IPC handler exposed over omarchy-shell"
      },
      {
        "source": "target:\\s*root\\.idPlugin\\b",
        "label": "ShellIpc target bound to the plugin id namespace"
      }
    ],
    "examples": [
      "  ShellIpc {",
      "    target: root.idPlugin",
      "    function toggle(): void { root.alternar() }",
      "    function mode(nuevo: string): void { root.establecerModo(nuevo) }",
      "    function volume(id: string, valor: int): void { root.establecerVolumen(id, valor) }",
      "    function joinRoom(texto: string): void { sala.unirse(texto) }",
      "    function authCallback(url: string): void { nube.recibirRetorno(url) }",
      "    function status(): string {"
    ],
    "closesSurfaceIds": [
      "shell-ipc-commands"
    ]
  },
  {
    "version": 1,
    "slug": "doro-auth-scheme-callback",
    "description": "The doro:// custom-scheme OAuth return path: the xdg-mime/.desktop registration of x-scheme-handler/doro, the authCallback IPC entry point, parsing of the redirect URL query and fragment into tokens, and installation of those tokens as the session. Triggerable by any web page or local process that opens a doro://auth URL.",
    "noiseTier": "precise",
    "filePatterns": [
      "**/*.qml",
      "Supabase.js"
    ],
    "requires": {
      "sentinelFiles": [
        "manifest.json"
      ]
    },
    "patterns": [
      {
        "source": "doro://auth",
        "label": "doro:// custom scheme used as the OAuth redirect target"
      },
      {
        "source": "x-scheme-handler/doro",
        "label": "xdg-mime registration of the doro:// scheme handler"
      },
      {
        "source": "\\b(?:recibirRetorno|parsearRetorno)\\s*\\(",
        "label": "OAuth return URL parsed into tokens"
      },
      {
        "source": "function\\s+authCallback\\s*\\(",
        "label": "authCallback IPC entry point for the browser redirect"
      },
      {
        "source": "establecerSesion\\s*\\(\\s*tokens\\b",
        "label": "Tokens from the callback URL installed as the session"
      },
      {
        "source": "redirect_to=",
        "label": "Supabase authorize redirect_to parameter"
      }
    ],
    "examples": [
      "var REDIRECCION = \"doro://auth\"",
      "  // `doro://auth` vuelve al plugin: un .desktop que pasa la URL por IPC.",
      "      'xdg-mime default doro-auth.desktop x-scheme-handler/doro']",
      "  function recibirRetorno(url) {",
      "    var retorno = Supabase.parsearRetorno(url, Date.now())",
      "    function authCallback(url: string): void { nube.recibirRetorno(url) }",
      "      establecerSesion(tokens)",
      "    \"&redirect_to=\" + encodeURIComponent(REDIRECCION) + \"&skip_http_redirect=true\""
    ],
    "closesSurfaceIds": [
      "doro-auth-url-callback"
    ]
  },
  {
    "version": 1,
    "slug": "supabase-rest-xhr-client",
    "description": "Hand-rolled XMLHttpRequest client against the shared Supabase project: request construction with apikey and Authorization bearer headers, the asegurarSesion/pedirConSesion session gate with its 401 refresh-and-retry, and the /auth/v1, /rest/v1 table and /rest/v1/rpc, /functions/v1 endpoint paths it calls.",
    "noiseTier": "normal",
    "filePatterns": [
      "**/*.qml",
      "Supabase.js"
    ],
    "requires": {
      "sentinelFiles": [
        "manifest.json"
      ]
    },
    "patterns": [
      {
        "source": "new\\s+XMLHttpRequest\\s*\\(",
        "label": "Raw XMLHttpRequest Supabase request"
      },
      {
        "source": "setRequestHeader\\s*\\(\\s*\"(?:apikey|Authorization)\"",
        "label": "Supabase apikey or bearer Authorization header set"
      },
      {
        "source": "\\bpedirConSesion\\s*\\(",
        "label": "Authenticated Supabase request wrapper"
      },
      {
        "source": "\\basegurarSesion\\s*\\(",
        "label": "Session-ensure gate before a Supabase call"
      },
      {
        "source": "/(?:auth|rest|functions)/v1/",
        "label": "Supabase auth, REST or edge-function endpoint path"
      },
      {
        "source": "/rest/v1/rpc/[a-z_]+",
        "label": "Supabase postgres RPC endpoint"
      }
    ],
    "examples": [
      "    var xhr = new XMLHttpRequest()",
      "    xhr.setRequestHeader(\"apikey\", conf.anonKey)",
      "    xhr.setRequestHeader(\"Authorization\", \"Bearer \" + (token || conf.anonKey))",
      "  function pedirConSesion(metodo, ruta, cuerpo, encabezados, crear, cb) {",
      "  function asegurarSesion(crear, cb) {",
      "      pedir(\"POST\", \"/auth/v1/token?grant_type=refresh_token\", { refresh_token: sesion.refresh_token }, null, null,",
      "      pedirConSesion(\"POST\", \"/rest/v1/study_sessions\", Supabase.filasSesiones(lote, usuario.id),",
      "    pedirConSesion(\"POST\", \"/functions/v1/sumar-anonimo\", { token_anonimo: tokenAnonimo }, null, false,",
      "    nube.pedirConSesion(\"POST\", \"/rest/v1/rpc/join_room\", { p_code: destino.codigo }, null, true, function(estado, datos) {",
      "  return base + \"/auth/v1/authorize?provider=\" + encodeURIComponent(proveedor) +"
    ],
    "closesSurfaceIds": [
      "supabase-rest-client"
    ]
  },
  {
    "version": 1,
    "slug": "supabase-realtime-phoenix-channel",
    "description": "Supabase Realtime subscription over the Phoenix protocol: the websocket endpoint with the anon key in its query, phx_join/phx_reply/phx_error frames, the postgres_changes config on the rooms row, outbound sendTextMessage frames, and the esEstadoReloj/aplicarRemoto validators that accept inbound timer_state from any room peer.",
    "noiseTier": "normal",
    "filePatterns": [
      "**/*.qml",
      "Model.js"
    ],
    "requires": {
      "sentinelFiles": [
        "manifest.json"
      ]
    },
    "patterns": [
      {
        "source": "\"(?:phx_join|phx_reply|phx_error|phx_close)\"",
        "label": "Phoenix channel control frame"
      },
      {
        "source": "postgres_changes",
        "label": "Realtime postgres_changes subscription config"
      },
      {
        "source": "realtime/v1/websocket",
        "label": "Supabase Realtime websocket endpoint"
      },
      {
        "source": "\\bsendTextMessage\\s*\\(",
        "label": "Outbound websocket frame"
      },
      {
        "source": "function\\s+(?:esEstadoReloj|aplicarRemoto|estadoParaSubir)\\s*\\(",
        "label": "Remote timer-state validator or serializer"
      },
      {
        "source": "Model\\.(?:esEstadoReloj|aplicarRemoto|estadoParaSubir)\\s*\\(",
        "label": "Inbound peer timer_state validated and applied"
      }
    ],
    "examples": [
      "      event: \"phx_join\",",
      "    if (mensaje.event === \"phx_reply\" && mensaje.ref === refUnion) {",
      "          postgres_changes: [{ event: \"UPDATE\", schema: \"public\", table: \"rooms\", filter: \"id=eq.\" + salaId }],",
      "      nuevo.url = nube.conf.url.replace(/^http/, \"ws\") + \"/realtime/v1/websocket?apikey=\" +",
      "    socket.sendTextMessage(JSON.stringify(mensaje))",
      "function esEstadoReloj(valor) {",
      "function aplicarRemoto(remoto, configuracionLocal, ahora) {",
      "    if (!Model.esEstadoReloj(estado)) return",
      "    var estado = Model.aplicarRemoto(remoto, configuracion, Date.now())"
    ],
    "closesSurfaceIds": [
      "realtime-room-channel"
    ]
  },
  {
    "version": 1,
    "slug": "qml-repeating-timer-job",
    "description": "QML Timer elements that act without user input: the Timer declaration, its repeat and interval schedule, and the onTriggered handler dispatching into the service, cloud or room objects. Covers the clock tick, debounced state save and room upload, the 2 s room poll, 5 s reconnect, 25 s heartbeat with watchdog, 30 s token refresh and the 5-minute offline-queue retry.",
    "noiseTier": "noisy",
    "filePatterns": [
      "**/*.qml"
    ],
    "requires": {
      "sentinelFiles": [
        "manifest.json"
      ]
    },
    "patterns": [
      {
        "source": "\\bTimer\\s*\\{",
        "label": "QML Timer declaration"
      },
      {
        "source": "repeat:\\s*true\\b",
        "label": "Repeating timer schedule"
      },
      {
        "source": "interval:\\s*\\d",
        "label": "Timer interval schedule"
      },
      {
        "source": "onTriggered:\\s*(?:root|nube|sala)\\.",
        "label": "Unattended timer action dispatched into service state"
      }
    ],
    "excludeFilePatterns": [
      "SonidoSinCortes.qml"
    ],
    "examples": [
      "  Timer {",
      "    repeat: true",
      "    interval: 2000",
      "    interval: 5 * 60 * 1000",
      "    onTriggered: root.subirPendientes()",
      "    onTriggered: root.traerEstado()",
      "    onTriggered: root.sala.subir(root.estadoLocal())",
      "    onTriggered: root.nube.asegurarSesion(false, function() {})"
    ],
    "closesSurfaceIds": [
      "timers-and-background-jobs"
    ]
  },
  {
    "version": 1,
    "slug": "qml-fileview-state-store",
    "description": "Quickshell FileView readers and writers for untrusted on-disk input, plus the pure parsers behind them: sesion.json (bearer tokens), pendientes.json, omarchy.json, the plugin-local .env and ~/.config/doro/supabase.json, which can repoint the backend URL and anon key.",
    "noiseTier": "normal",
    "filePatterns": [
      "**/*.qml",
      "Supabase.js",
      "Model.js"
    ],
    "requires": {
      "sentinelFiles": [
        "manifest.json"
      ]
    },
    "patterns": [
      {
        "source": "\\bFileView\\s*\\{",
        "label": "Quickshell FileView state file reader or writer"
      },
      {
        "source": "(?:sesion|pendientes|omarchy|supabase)\\.json\\b",
        "label": "Plugin state or backend-config file path"
      },
      {
        "source": "function\\s+(?:estadoGuardado|sesionGuardada|pendientesGuardados|leerEnv|configuracionEnv)\\s*\\(",
        "label": "Parser for on-disk state, session or env input"
      },
      {
        "source": "Supabase\\.(?:sesionGuardada|pendientesGuardados|configuracionEnv|configuracion)\\s*\\(",
        "label": "On-disk session or backend config loaded into the client"
      },
      {
        "source": "Model\\.estadoGuardado\\s*\\(",
        "label": "Saved timer state rehydrated from disk"
      },
      {
        "source": "setText\\s*\\(\\s*JSON\\.stringify",
        "label": "Session or state serialized to disk"
      },
      {
        "source": "atomicWrites:\\s*true\\b",
        "label": "FileView atomic write of plugin state"
      }
    ],
    "examples": [
      "  FileView {",
      "    path: root.carpetaEstado + \"/omarchy.json\"",
      "    path: root.listo ? root.carpetaEstado + \"/sesion.json\" : \"\"",
      "  readonly property string rutaConf: (Quickshell.env(\"XDG_CONFIG_HOME\") || (Quickshell.env(\"HOME\") + \"/.config\")) + \"/doro/supabase.json\"",
      "function sesionGuardada(texto) {",
      "function estadoGuardado(texto) {",
      "function leerEnv(texto) {",
      "    onLoaded: if (!root.sesionLeida) { root.sesion = Supabase.sesionGuardada(text()); root.sesionLeida = true }",
      "    var estado = Model.estadoGuardado(texto)",
      "    archivoSesion.setText(JSON.stringify(nueva, null, 2))",
      "    atomicWrites: true"
    ],
    "closesSurfaceIds": [
      "local-state-and-config-files"
    ]
  },
  {
    "version": 1,
    "slug": "qml-subprocess-desktop-exec",
    "description": "Processes the plugin spawns with partly remote-influenced arguments: Quickshell.execDetached and Quickshell Process command arrays for xdg-open (server-provided sign-in URL, dashboard), wl-copy (room invite link), omarchy-notification-send, omarchy bar set, mkdir/chmod of the token directory, and the sh -c that installs the doro:// handler; plus the dev install script.",
    "noiseTier": "normal",
    "filePatterns": [
      "**/*.qml",
      "scripts/*.sh"
    ],
    "requires": {
      "sentinelFiles": [
        "manifest.json"
      ]
    },
    "patterns": [
      {
        "source": "Quickshell\\.execDetached\\s*\\(",
        "label": "Detached subprocess spawned from QML"
      },
      {
        "source": "\\bProcess\\s*\\{",
        "label": "Quickshell Process declaration"
      },
      {
        "source": "command:\\s*\\[\\s*\"",
        "label": "Process command argv array"
      },
      {
        "source": "\"sh\"\\s*,\\s*\"-c\"",
        "label": "Shell interpreter subprocess"
      },
      {
        "source": "\\b(?:xdg-open|wl-copy|xdg-mime|omarchy-notification-send)\\b",
        "label": "Desktop integration tool invoked with argv"
      },
      {
        "source": "omarchy(?:-shell)?\\s+(?:plugin|shell)\\s+(?:validate|enable|list|rescanPlugins)\\b",
        "label": "Omarchy plugin or shell command run by the install script"
      },
      {
        "source": "rsync\\s+-a\\s+--delete\\b",
        "label": "Install script mirroring the repo into the plugin directory"
      }
    ],
    "examples": [
      "    Quickshell.execDetached([\"xdg-open\", url])",
      "    if (link) Quickshell.execDetached([\"wl-copy\", link])",
      "    Quickshell.execDetached([\"omarchy-notification-send\", \"--app-name\", \"Doro\", \"--image\", rutaIconoAviso,",
      "    Quickshell.execDetached([\"omarchy\", \"bar\", \"set\", idPlugin, \"language\", nuevo])",
      "  Process {",
      "    command: [\"mkdir\", \"-p\", root.carpetaEstado]",
      "    command: [\"chmod\", \"700\", root.carpetaEstado]",
      "    command: [\"sh\", \"-c\",",
      "      'xdg-mime default doro-auth.desktop x-scheme-handler/doro']",
      "omarchy plugin validate \"$destino\"",
      "  omarchy-shell shell rescanPlugins",
      "rsync -a --delete --delete-excluded --exclude .git \"$repo/\" \"$destino/\""
    ],
    "closesSurfaceIds": [
      "subprocess-and-desktop-integration"
    ]
  }
];

export const generatedMatchersPlugin: DeepsecPlugin = {
  name: "deepsec-generated-matchers",
  matchers: compileDeclarativeMatchers(specs),
};
