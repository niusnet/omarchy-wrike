import QtQuick
import qs.Commons

Column {
  id: root

  property var sections: []
  property var collapsedTitles: ({})
  property string highlightedKey: ""
  property string confirmedKey: ""
  property string confirmation: ""
  property color foreground: "white"
  property string fontFamily: ""

  signal ticketActivated(string key)
  signal ticketKeyRequested(string key)
  signal sectionToggled(string title)

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  Repeater {
    model: root.sections

    TaskList {
      required property var modelData

      width: root.width
      title: String(modelData.title || "")
      tickets: modelData.tickets || []
      collapsed: root.collapsedTitles && root.collapsedTitles[String(modelData.title || "")] === true
      highlightedKey: root.highlightedKey
      confirmedKey: root.confirmedKey
      confirmation: root.confirmation
      foreground: root.foreground
      fontFamily: root.fontFamily
      onTicketActivated: function (key) { root.ticketActivated(key) }
      onTicketKeyRequested: function (key) { root.ticketKeyRequested(key) }
      onToggleRequested: root.sectionToggled(String(modelData.title || ""))
    }
  }
}
