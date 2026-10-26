import QtQuick

// El logo de Doro (`public/doro.svg`): un anillo con un arco adentro. Dibujado
// en vez de cargado como imagen para que tome los colores del tema de Omarchy.
// Con `avance` el anillo de afuera se va llenando con el acento, desde arriba.
Canvas {
  id: root

  property color color: "white"
  property color acento: color
  // 0 a 1, o null para el anillo entero (sin fase en curso o cronómetro).
  property var avance: null
  property real grosor: Math.max(1.5, width / 12)

  implicitWidth: 16
  implicitHeight: 16
  antialiasing: true

  onColorChanged: requestPaint()
  onAcentoChanged: requestPaint()
  onAvanceChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    var lado = Math.min(width, height)
    // El SVG es de 24 con trazo 2: radios 9 y 6 sobre el centro.
    var escala = lado / 24
    var cx = width / 2
    var cy = height / 2
    ctx.lineWidth = root.grosor
    ctx.lineCap = "round"

    var hayAvance = root.avance !== null && root.avance !== undefined
    ctx.strokeStyle = hayAvance ? Qt.rgba(root.color.r, root.color.g, root.color.b, 0.3) : root.color
    ctx.beginPath()
    ctx.arc(cx, cy, 9 * escala, 0, Math.PI * 2, false)
    ctx.stroke()

    if (hayAvance && root.avance > 0) {
      ctx.strokeStyle = root.acento
      ctx.beginPath()
      ctx.arc(cx, cy, 9 * escala, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * root.avance, false)
      ctx.stroke()
    }

    ctx.strokeStyle = root.color
    ctx.beginPath()
    ctx.arc(cx, cy, 6 * escala, -Math.PI / 4, -Math.PI * 3 / 4, true)
    ctx.stroke()
  }
}
