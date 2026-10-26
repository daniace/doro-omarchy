import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

// El panel de Doro: la fase, el reloj grande con su hilo, los controles y, a
// pedido, los tiempos y los sonidos ambientales. Lee y maneja `reloj`
// (Service.qml); no guarda estado propio salvo qué sección está abierta.
Panel {
  id: root
  moduleName: "page.doro.pomodoro"
  ipcTarget: "page.doro.pomodoro"
  // El destino IPC es del servicio, que hay uno solo; este panel hay uno por monitor.
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var reloj: null
  readonly property var barIdentity: hostWidget || root

  // "" | "tiempos" | "sonidos"
  property string seccion: ""

  // ---- Sonidos (la vista del mezclador de la web, `MusicPlayer.tsx`)
  readonly property int volumenAlPrender: 45
  // La grilla muestra 8 hasta que se pide ver todos.
  property bool verTodos: false
  // Los que suenan, en el orden del catálogo, como texto: un string solo avisa
  // cuando cambia, así que mover un volumen no rearma los renglones (ni el
  // slider que se está arrastrando); prender o apagar uno, sí.
  readonly property string idsSonando: {
    if (!reloj) return ""
    var ids = []
    for (var i = 0; i < reloj.sonidosAmbiente.length; i++) {
      var id = reloj.sonidosAmbiente[i].id
      if ((reloj.mezcla[id] || 0) > 0) ids.push(id)
    }
    return ids.join(",")
  }

  function sonidoPorId(id) {
    var lista = reloj ? reloj.sonidosAmbiente : []
    for (var i = 0; i < lista.length; i++) if (lista[i].id === id) return lista[i]
    return { id: id, nombre: id, icono: "" }
  }

  readonly property color texto: bar ? bar.foreground : Color.foreground
  readonly property color apagado: Qt.rgba(texto.r, texto.g, texto.b, 0.6)
  readonly property color linea: Qt.rgba(texto.r, texto.g, texto.b, 0.15)
  readonly property color acento: Color.accent
  readonly property string fuente: bar ? bar.fontFamily : Style.font.family

  function open() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { if (root.opened) root.close(); else root.open() }
  function alternarSeccion(nombre) { seccion = seccion === nombre ? "" : nombre }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      implicitHeight: columna.implicitHeight
      anchors.fill: parent
      onCloseRequested: root.close()
      onReturnRequested: if (root.reloj) root.reloj.alternar()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: columna
        width: parent.width
        spacing: Style.space(14)

        // ---- La fase: un punto en el acento y el nombre; tocarlo pasa a la siguiente.
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(4)

          Rectangle {
            id: fase
            width: filaFase.implicitWidth + Style.space(16)
            height: filaFase.implicitHeight + Style.space(10)
            radius: Style.cornerRadius > 0 ? Style.space(6) : 0
            color: zonaFase.containsMouse && !esCronometro ? root.linea : "transparent"
            readonly property bool esCronometro: root.reloj !== null && root.reloj.modo === "stopwatch"

            Row {
              id: filaFase
              anchors.centerIn: parent
              spacing: Style.space(8)

              Rectangle {
                id: punto
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(6)
                height: width
                radius: width / 2
                color: root.acento

                // Late con el reloj corriendo, como en la web.
                SequentialAnimation on opacity {
                  running: root.reloj !== null && root.reloj.estaActivo
                  loops: Animation.Infinite
                  onRunningChanged: if (!running) punto.opacity = 1
                  NumberAnimation { to: 0.35; duration: 1200; easing.type: Easing.InOutSine }
                  NumberAnimation { to: 1; duration: 1200; easing.type: Easing.InOutSine }
                }
              }

              Text {
                text: root.reloj ? root.reloj.etiquetaModo.toUpperCase() : ""
                color: zonaFase.containsMouse && !fase.esCronometro ? root.texto : root.apagado
                font.family: root.fuente
                font.pixelSize: Style.font.bodySmall
                font.letterSpacing: Style.font.bodySmall * 0.15
              }
            }

            MouseArea {
              id: zonaFase
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: fase.esCronometro ? Qt.ArrowCursor : Qt.PointingHandCursor
              onClicked: if (root.reloj && !fase.esCronometro) root.reloj.siguienteModo()
            }
          }

          PanelActionButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: root.reloj && root.reloj.modo === "stopwatch" ? "\u{f0141}" : "\u{f0142}"
            tooltipText: root.reloj && root.reloj.modo === "stopwatch" ? "Volver al pomodoro" : "Pasar a cronómetro"
            foreground: root.apagado
            hoverColor: root.texto
            fontFamily: root.fuente
            fontSize: Style.font.body
            onClicked: if (root.reloj) root.reloj.alternarCronometro()
          }
        }

        // ---- El reloj, MM:SS, con el hilo de la fase debajo.
        Item {
          width: parent.width
          height: numeros.implicitHeight + Style.space(10)

          Text {
            id: numeros
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.reloj ? root.reloj.texto : "--:--"
            color: root.reloj && root.reloj.sinEmpezar ? Qt.rgba(root.texto.r, root.texto.g, root.texto.b, 0.88) : root.texto
            font.family: root.fuente
            font.pixelSize: Style.space(64)
            font.weight: Font.DemiBold
            font.letterSpacing: -Style.space(2)
            font.features: { "tnum": 1 }
            scale: root.reloj && root.reloj.estaActivo ? 1.035 : 1
            Behavior on scale { NumberAnimation { duration: 900; easing.type: Easing.OutExpo } }
          }

          Rectangle {
            id: hilo
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: numeros.paintedWidth * 0.9
            height: 2
            radius: 1
            color: root.linea
            visible: root.reloj !== null && root.reloj.avance !== null
            opacity: root.reloj && root.reloj.estaActivo ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 600 } }

            Rectangle {
              height: parent.height
              radius: 1
              color: root.acento
              width: parent.width * (root.reloj && root.reloj.avance !== null ? root.reloj.avance : 0)
              Behavior on width { NumberAnimation { duration: 1000 } }
            }
          }
        }

        // ---- Controles: arrancar/pausar en el acento, reiniciar, tiempos y sonidos.
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: Style.space(8)

          Rectangle {
            id: botonPlay
            readonly property bool corriendo: root.reloj !== null && root.reloj.estaActivo
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(52)
            height: Style.space(36)
            radius: Style.cornerRadius > 0 ? Style.space(8) : 0
            color: corriendo ? "transparent" : (zonaPlay.containsMouse ? Qt.lighter(root.acento, 1.12) : root.acento)
            border.width: corriendo ? 1 : 0
            border.color: root.linea

            Text {
              anchors.centerIn: parent
              text: botonPlay.corriendo ? "\u{f03e4}" : "\u{f040a}"
              color: botonPlay.corriendo ? root.texto : (bar ? bar.background : Color.background)
              font.family: root.fuente
              font.pixelSize: Style.font.heading
            }

            MouseArea {
              id: zonaPlay
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.reloj) root.reloj.alternar()
            }
          }

          PanelActionButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: "\u{f0450}"
            tooltipText: "Reiniciar"
            foreground: root.apagado
            hoverColor: root.texto
            fontFamily: root.fuente
            onClicked: if (root.reloj) root.reloj.reiniciar()
          }

          PanelActionButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: "\u{f0493}"
            tooltipText: "Tiempos"
            foreground: root.seccion === "tiempos" ? root.acento : root.apagado
            hoverColor: root.seccion === "tiempos" ? root.acento : root.texto
            fontFamily: root.fuente
            onClicked: root.alternarSeccion("tiempos")
          }

          PanelActionButton {
            anchors.verticalCenter: parent.verticalCenter
            iconText: root.reloj && root.reloj.hayAmbienteActivo ? "\u{f057e}" : "\u{f0581}"
            tooltipText: "Sonidos"
            foreground: root.seccion === "sonidos" || (root.reloj && root.reloj.hayAmbienteActivo) ? root.acento : root.apagado
            hoverColor: root.seccion === "sonidos" ? root.acento : root.texto
            fontFamily: root.fuente
            onClicked: root.alternarSeccion("sonidos")
          }
        }

        // ---- Tiempos: un renglón por fase (− número +) y el descanso automático.
        Column {
          visible: root.seccion === "tiempos"
          width: parent.width
          spacing: 0

          Repeater {
            model: [
              { clave: "pomodoro", nombre: "Pomodoro" },
              { clave: "shortBreak", nombre: "Descanso corto" },
              { clave: "longBreak", nombre: "Descanso largo" }
            ]

            Item {
              required property var modelData
              width: parent.width
              height: Style.space(40)

              Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.nombre
                color: root.texto
                font.family: root.fuente
                font.pixelSize: Style.font.body
              }

              Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                PanelActionButton {
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: "\u{f0374}"
                  tooltipText: modelData.nombre + ": un minuto menos"
                  foreground: root.apagado
                  hoverColor: root.texto
                  fontFamily: root.fuente
                  fontSize: Style.font.body
                  onClicked: root.reloj.establecerMinutos(modelData.clave, root.reloj.configuracion[modelData.clave] - 1)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(32)
                  horizontalAlignment: Text.AlignHCenter
                  text: root.reloj ? root.reloj.configuracion[modelData.clave] : ""
                  color: root.texto
                  font.family: root.fuente
                  font.pixelSize: Style.font.title
                  font.weight: Font.DemiBold
                }

                PanelActionButton {
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: "\u{f0415}"
                  tooltipText: modelData.nombre + ": un minuto más"
                  foreground: root.apagado
                  hoverColor: root.texto
                  fontFamily: root.fuente
                  fontSize: Style.font.body
                  onClicked: root.reloj.establecerMinutos(modelData.clave, root.reloj.configuracion[modelData.clave] + 1)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "min"
                  color: root.apagado
                  font.family: root.fuente
                  font.pixelSize: Style.font.caption
                }
              }

              Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.linea
              }
            }
          }

          Item {
            width: parent.width
            height: Style.space(44)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Arrancar el descanso solo"
              color: root.texto
              font.family: root.fuente
              font.pixelSize: Style.font.body
            }

            ToggleSwitch {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              checked: root.reloj ? root.reloj.configuracion.autoBreak : false
              foreground: root.texto
              accent: root.acento
              cursorRing: false
              onToggled: root.reloj.establecerAutoBreak(!checked)
            }
          }
        }

        // ---- Sonidos ambientales: volumen por sonido y «Pausar todo».
        Column {
          visible: root.seccion === "sonidos"
          width: parent.width
          spacing: Style.space(2)

          Item {
            width: parent.width
            height: Style.space(36)

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: "Sonidos"
              color: root.apagado
              font.family: root.fuente
              font.pixelSize: Style.font.caption
              font.letterSpacing: Style.font.caption * 0.15
              font.capitalization: Font.AllUppercase
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              visible: root.reloj !== null && Object.keys(root.reloj.mezcla).length > 0
              text: root.reloj && root.reloj.ambienteActivo ? "Pausar todo" : "Reanudar"
              color: zonaPausarTodo.containsMouse ? root.texto : root.acento
              font.family: root.fuente
              font.pixelSize: Style.font.bodySmall

              MouseArea {
                id: zonaPausarTodo
                anchors.fill: parent
                anchors.margins: -Style.space(6)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.reloj.alternarAmbiente()
              }
            }
          }

          // Arriba, solo los que suenan: volumen y una × para apagarlos.
          Repeater {
            model: root.idsSonando === "" ? [] : root.idsSonando.split(",")

            Item {
              required property string modelData
              readonly property var sonido: root.sonidoPorId(modelData)
              width: parent.width
              height: Style.space(30)

              Text {
                id: icono
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(22)
                text: sonido.icono
                color: root.acento
                font.family: root.fuente
                font.pixelSize: Style.font.title
              }

              Text {
                id: nombre
                anchors.left: icono.right
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(88)
                text: sonido.nombre
                color: root.texto
                font.family: root.fuente
                font.pixelSize: Style.font.bodySmall
                elide: Text.ElideRight
              }

              PanelSlider {
                anchors.left: nombre.right
                anchors.right: apagar.left
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                bar: root.bar
                minimum: 0
                maximum: 100
                step: 5
                integer: true
                value: root.reloj ? (root.reloj.mezcla[modelData] || 0) : 0
                fillColor: root.acento
                // Mientras se arrastra no baja de 5: llegar a 0 saca el renglón, y no
                // puede desaparecer el slider que se está arrastrando. Al soltar en 0 se apaga.
                onMoved: function(valor) { root.reloj.establecerVolumen(modelData, Math.max(5, valor)) }
                onReleased: function(valor) { root.reloj.establecerVolumen(modelData, valor) }
              }

              PanelActionButton {
                id: apagar
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: "\u{f0156}"
                tooltipText: "Apagar " + sonido.nombre
                foreground: root.apagado
                hoverColor: root.texto
                fontFamily: root.fuente
                fontSize: Style.font.body
                onClicked: root.reloj.establecerVolumen(modelData, 0)
              }
            }
          }

          // Abajo, la grilla: un clic prende en 45 (como en la web) o apaga.
          Grid {
            id: grilla
            columns: 4
            width: parent.width
            topPadding: root.idsSonando === "" ? 0 : Style.space(6)

            Repeater {
              model: root.reloj
                ? (root.verTodos ? root.reloj.sonidosAmbiente : root.reloj.sonidosAmbiente.slice(0, 8))
                : []

              Rectangle {
                id: mosaico
                required property var modelData
                readonly property bool prendido: root.reloj ? (root.reloj.mezcla[modelData.id] || 0) > 0 : false
                width: grilla.width / grilla.columns
                height: Style.space(52)
                radius: Style.cornerRadius > 0 ? Style.space(6) : 0
                color: zonaMosaico.containsMouse ? root.linea : "transparent"

                Column {
                  anchors.centerIn: parent
                  width: parent.width
                  spacing: Style.space(4)

                  Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: mosaico.modelData.icono
                    color: mosaico.prendido ? root.acento : (zonaMosaico.containsMouse ? root.texto : root.apagado)
                    font.family: root.fuente
                    font.pixelSize: Style.font.title
                  }

                  Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: mosaico.modelData.nombre
                    color: mosaico.prendido || zonaMosaico.containsMouse ? root.texto : root.apagado
                    font.family: root.fuente
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }

                MouseArea {
                  id: zonaMosaico
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.reloj.establecerVolumen(mosaico.modelData.id, mosaico.prendido ? 0 : root.volumenAlPrender)
                }
              }
            }
          }

          Text {
            visible: !root.verTodos && root.reloj !== null && root.reloj.sonidosAmbiente.length > 8
            text: "Ver los " + (root.reloj ? root.reloj.sonidosAmbiente.length : 0)
            color: zonaVerTodos.containsMouse ? root.texto : root.apagado
            font.family: root.fuente
            font.pixelSize: Style.font.bodySmall
            topPadding: Style.space(4)

            MouseArea {
              id: zonaVerTodos
              anchors.fill: parent
              anchors.margins: -Style.space(4)
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.verTodos = true
            }
          }
        }
      }
    }
  }
}
