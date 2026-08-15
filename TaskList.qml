import QtQuick
import qs.Commons
import qs.Ui

Column {
  id: root

  property string title: ""
  property var tickets: []
  property string highlightedKey: ""
  property string confirmedKey: ""
  property string confirmation: ""
  property color foreground: "white"
  property string fontFamily: ""

  signal ticketActivated(string key)
  signal ticketKeyRequested(string key)

  readonly property int count: tickets ? tickets.length : 0

  width: parent ? parent.width : 0
  spacing: Style.space(2)
  visible: count > 0

  PanelSectionHeader {
    width: parent.width
    text: root.title + "  " + root.count
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  Repeater {
    model: root.tickets

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
