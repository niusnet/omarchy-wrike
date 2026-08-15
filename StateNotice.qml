import QtQuick
import qs.Commons

Column {
  id: root

  property string state: "loading"
  property string message: ""
  property string fetchedAt: ""
  property bool hasStaleData: false
  property bool searchActive: false
  property color foreground: "white"
  property string fontFamily: ""

  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.9)

  readonly property string headline: {
    switch (state) {
    case "loading":
      return qsTr("Loading")
    case "searching":
      return qsTr("Searching")
    case "ok":
      return searchActive ? qsTr("No results") : qsTr("Nothing on your plate")
    case "unconfigured":
      return qsTr("Not connected")
    case "keyring-unavailable":
      return qsTr("Keyring unavailable")
    case "unauthorized":
      return qsTr("Token rejected")
    case "forbidden":
      return qsTr("Not permitted")
    case "network-error":
      return qsTr("Wrike unreachable")
    default:
      return qsTr("Something went wrong")
    }
  }

  readonly property string detail: {
    if (state === "searching")
      return qsTr("Asking Wrike.")
    if (state === "ok" && searchActive)
      return qsTr("No task matches that search.")
    if (state === "ok")
      return qsTr("No tasks are assigned to you right now.")
    if (message !== "")
      return message
    return ""
  }

  readonly property string command: {
    if (state === "unconfigured" || state === "unauthorized")
      return "omarchy-wrike-auth"
    return ""
  }

  width: parent ? parent.width : 0
  spacing: Style.space(3)

  Text {
    width: parent.width
    text: root.headline
    color: root.state === "ok" ? root.muted : root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    font.bold: true
    wrapMode: Text.WordWrap
  }

  Text {
    width: parent.width
    visible: root.detail !== ""
    text: root.detail
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Rectangle {
    visible: root.command !== ""
    width: commandLabel.width + Style.space(6)
    height: commandLabel.height + Style.space(3)
    radius: Style.cornerRadius
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

    Text {
      id: commandLabel

      anchors.centerIn: parent
      text: root.command
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Text {
    width: parent.width
    visible: root.hasStaleData && root.fetchedAt !== ""
    text: qsTr("Showing the last successful refresh.")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
