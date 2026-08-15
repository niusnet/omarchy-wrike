import QtQuick
import qs.Commons
import "Model.js" as Model

Column {
  id: root

  property var ticket: null
  property bool loading: false
  property color foreground: "white"
  property string fontFamily: ""

  signal backRequested()
  signal openRequested()

  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.9)
  readonly property string bodyText: {
    if (!ticket)
      return ""
    var full = Model.stripHtml(ticket.description)
    if (full !== "")
      return full
    return Model.stripHtml(ticket.brief)
  }

  width: parent ? parent.width : 0
  spacing: Style.space(8)

  Row {
    width: parent.width
    spacing: Style.space(4)

    Text {
      text: qsTr("← Back")
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      TapHandler { onTapped: root.backRequested() }
    }

    Text {
      text: qsTr("Open in Wrike")
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      TapHandler { onTapped: root.openRequested() }
    }
  }

  Text {
    width: parent.width
    text: ticket ? String(ticket.summary || "") : ""
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.body
    font.bold: true
    wrapMode: Text.WordWrap
  }

  Text {
    width: parent.width
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    text: {
      if (!ticket)
        return ""
      var parts = []
      if (String(ticket.key || "") !== "")
        parts.push("#" + String(ticket.key))
      if (String(ticket.status || "") !== "")
        parts.push(String(ticket.status))
      if (String(ticket.projectName || "") !== "")
        parts.push(String(ticket.projectName))
      if (String(ticket.due || "") !== "")
        parts.push(qsTr("due ") + String(ticket.due).slice(0, 10))
      if (String(ticket.age || "") !== "")
        parts.push(String(ticket.age))
      return parts.join("  ·  ")
    }
  }

  Text {
    width: parent.width
    visible: root.loading && root.bodyText === ""
    text: qsTr("Loading description")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    width: parent.width
    visible: root.bodyText !== ""
    text: root.bodyText
    color: root.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  Text {
    width: parent.width
    visible: !root.loading && root.bodyText === ""
    text: qsTr("No description on this task.")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
