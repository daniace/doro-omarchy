import QtQuick
import qs.Commons
import qs.Ui

// Doro en la barra: el anillo, que se llena con la fase, y el tiempo al lado
// cuando hay una fase en curso. Es solo una vista del servicio (Service.qml).
//
// Clic izquierdo abre el panel, derecho arranca o pausa, medio pasa de fase.
BarWidget {
  id: root
  moduleName: "doro.pomodoro"

  // El host puede cambiar `moduleName` por un id de instancia; el del manifest
  // es el que sirve para buscar el servicio.
  readonly property string idPlugin: "doro.pomodoro"
  readonly property var reloj: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(idPlugin)
    : null

  readonly property bool muestraTiempo: !vertical && reloj !== null && !reloj.sinEmpezar
  readonly property bool enSala: reloj !== null && reloj.sala.salaId !== ""

  // ---- Panel. Contrato de shell.summon/hide/toggle: Bar.findPanelWidget pide
  //      open/close/opened en la raíz del widget.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }

  // Para que el widget pueda hacer de identidad del panel en la barra:
  // Bar.requestPopout prefiere closeForPopoutSwitch a close.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("reloj" in target) target.reloj = root.reloj
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onRelojChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    active: root.reloj !== null && root.reloj.estaActivo
    useActiveColor: false
    fixedWidth: root.vertical ? -1 : contenido.implicitWidth + scaledHorizontalMargin * 2
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1
    horizontalMargin: 8.75
    tooltipText: root.reloj
      ? root.reloj.etiquetaModo + (root.reloj.estaActivo ? "" : " · en pausa") + (root.enSala ? " · en sala" : "")
      : "Doro"

    onPressed: function(b) {
      if (!root.reloj) return
      if (b === Qt.RightButton) root.reloj.alternar()
      else if (b === Qt.MiddleButton) root.reloj.siguienteModo()
      else root.togglePanel()
    }

    Row {
      id: contenido
      anchors.centerIn: parent
      spacing: Style.space(6)

      AnilloDoro {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(button.fontSize * 1.25)
        height: width
        color: button.foreground
        acento: Color.accent
        avance: root.reloj && !root.reloj.sinEmpezar ? root.reloj.avance : null
      }

      Text {
        visible: root.muestraTiempo
        anchors.verticalCenter: parent.verticalCenter
        text: root.reloj ? root.reloj.texto : ""
        color: button.foreground
        opacity: root.reloj && root.reloj.estaActivo ? 1 : 0.6
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        font.features: { "tnum": 1 }
        renderType: Text.NativeRendering
      }

      // En una sala: el reloj es compartido.
      Text {
        visible: root.enSala && !root.vertical
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{f0849}"
        color: Color.accent
        font.family: button.fontFamily
        font.pixelSize: Math.round(button.fontSize * 0.85)
        renderType: Text.NativeRendering
      }
    }
  }
}
