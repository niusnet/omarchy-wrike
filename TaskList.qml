import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root

  property string title: ""
  property var tickets: []
  property bool collapsed: false
  property string highlightedKey: ""
  property string confirmedKey: ""
  property string confirmation: ""
  property color foreground: "white"
  property string fontFamily: ""

  signal ticketActivated(string key)
  signal ticketKeyRequested(string key)
  signal toggleRequested()

  readonly property int count: tickets ? tickets.length : 0
  readonly property color muted: Qt.darker(foreground, 1.5)

  width: parent ? parent.width : 0
  spacing: Style.space(2)
  visible: count > 0

  Rectangle {
    width: parent.width
    height: headerRow.implicitHeight + Style.space(4)
    radius: Style.cornerRadius
    color: headerHover.hovered
      ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
      : "transparent"

    HoverHandler { id: headerHover }
    TapHandler { onTapped: root.toggleRequested() }

    Row {
      id: headerRow
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(6)

      Text {
        text: root.collapsed ? "▸" : "▾"
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      PanelSectionHeader {
        width: parent.width - Style.space(16)
        text: root.title + "  " + root.count
        foreground: root.foreground
        fontFamily: root.fontFamily
      }
    }
  }

  Repeater {
    model: root.collapsed ? [] : root.tickets

    TaskRow {
      required property var modelData

      ticket: modelData
      highlighted: root.highlightedKey !== "" && root.highlightedKey === String(modelData.key || "")
      confirmation: root.confirmedKey !== "" && root.confirmedKey === String(modelData.key || "")
        ? root.confirmation
        : ""
      foreground: root.foreground
      fontFamily: root.fontFamily
      onActivated: root.ticketActivated(String(modelData.key || ""))
      onKeyRequested: root.ticketKeyRequested(String(modelData.key || ""))
    }
  }
}
