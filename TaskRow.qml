import QtQuick
import qs.Commons

Rectangle {
  id: root

  property var ticket: null
  property bool highlighted: false
  property color foreground: "white"
  property string fontFamily: ""
  property string confirmation: ""

  signal activated()
  signal keyRequested()

  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.9)
  readonly property string ticketKey: ticket ? String(ticket.key || "") : ""
  readonly property bool remote: ticket ? ticket.remote === true : false

  function typeGlyph(type) {
    var name = String(type || "").toLowerCase()
    if (name === "milestone")
      return "\uf024"
    if (name === "planned")
      return "\uf0ae"
    return "\uf03a"
  }

  width: parent ? parent.width : 0
  height: body.implicitHeight + Style.space(6)
  radius: Style.cornerRadius
  color: highlighted || hover.hovered
    ? Qt.rgba(foreground.r, foreground.g, foreground.b, highlighted ? 0.1 : 0.05)
    : "transparent"

  HoverHandler { id: hover }

  TapHandler {
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
    onTapped: function (point, button) {
      if (button === Qt.MiddleButton)
        root.keyRequested()
      else
        root.activated()
    }
  }

  Row {
    id: body

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: Style.space(3)
    anchors.rightMargin: Style.space(3)
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(4)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(8)
      text: root.typeGlyph(root.ticket ? root.ticket.type : "")
      color: root.faint
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: body.width - Style.space(16)
      spacing: Style.space(1)

      Row {
        width: parent.width
        spacing: Style.space(3)

        Text {
          id: keyLabel

          text: root.ticketKey
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }

        Text {
          width: parent.width - keyLabel.width - Style.space(3)
          text: root.ticket ? String(root.ticket.summary || "") : ""
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }
      }

      Text {
        width: parent.width
        color: root.faint
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
        text: {
          if (root.confirmation !== "")
            return root.confirmation
          if (!root.ticket)
            return ""
          var parts = []
          if (String(root.ticket.spaceName || "") !== "")
            parts.push(String(root.ticket.spaceName))
          if (String(root.ticket.projectName || "") !== "" && String(root.ticket.projectName) !== String(root.ticket.spaceName || ""))
            parts.push(String(root.ticket.projectName))
          if (String(root.ticket.status || "") !== "")
            parts.push(String(root.ticket.status))
          if (String(root.ticket.age || "") !== "")
            parts.push(String(root.ticket.age))
          return parts.join("  ·  ")
        }
      }
    }
  }
}
