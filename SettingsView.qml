import QtQuick
import qs.Commons

Column {
  id: root

  property color foreground: "white"
  property string fontFamily: ""

  property var projects: []
  property var followedSpaces: []
  property string site: ""
  property string account: ""
  property string state: "ok"

  property bool connecting: false
  property string authMessage: ""

  signal spaceToggled(string key)
  signal allSpacesCleared()
  signal connectRequested(string host, string token)
  signal disconnectRequested()

  readonly property bool inputFocused: hostInput.activeFocus || tokenInput.activeFocus

  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.9)
  readonly property bool followingAll: !followedSpaces || followedSpaces.length === 0

  function isFollowed(key) {
    if (followingAll)
      return true
    for (var i = 0; i < followedSpaces.length; i++) {
      if (String(followedSpaces[i]).toLowerCase() === String(key).toLowerCase())
        return true
    }
    return false
  }

  spacing: Style.space(8)

  component SectionTitle: Text {
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.letterSpacing: 1
    font.bold: true
  }

  component ToggleRow: Rectangle {
    id: toggle

    property string label: ""
    property string hint: ""
    property bool checked: false

    signal activated()

    width: parent ? parent.width : 0
    height: toggleBody.height + Style.space(4)
    radius: Style.cornerRadius
    color: hovered.hovered
      ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
      : "transparent"

    HoverHandler { id: hovered }
    TapHandler { onTapped: toggle.activated() }

    Row {
      id: toggleBody

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.leftMargin: Style.space(3)
      anchors.rightMargin: Style.space(3)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(3)

      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(8)
        text: toggle.checked ? "\uf14a" : "\uf096"
        color: toggle.checked ? root.foreground : root.faint
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: toggleBody.width - Style.space(14)
        spacing: Style.space(1)

        Text {
          width: parent.width
          text: toggle.label
          color: toggle.checked ? root.foreground : root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          visible: toggle.hint !== ""
          text: toggle.hint
          color: root.faint
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  SectionTitle { text: qsTr("SPACES") }

  Text {
    width: parent.width
    text: root.followingAll
      ? qsTr("Every space is included. Untick the ones you do not care about.")
      : qsTr("Ticked spaces feed your lists and lead your search results. The others stay searchable.")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Text {
    width: parent.width
    visible: !root.projects || root.projects.length === 0
    text: qsTr("No spaces loaded yet.")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Repeater {
    model: root.projects

    ToggleRow {
      required property var modelData

      label: String(modelData.name || modelData.key || "")
      hint: String(modelData.key || "")
      checked: root.isFollowed(String(modelData.key || ""))
      onActivated: root.spaceToggled(String(modelData.key || ""))
    }
  }

  ToggleRow {
    visible: !root.followingAll
    label: qsTr("Include every space")
    hint: qsTr("Clears the selection above")
    checked: false
    onActivated: root.allSpacesCleared()
  }

  SectionTitle { text: qsTr("CONNECTION") }

  Text {
    width: parent.width
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    text: {
      if (root.authMessage !== "")
        return root.authMessage
      if (root.state === "unconfigured")
        return qsTr("Not connected. Paste a permanent token below.")
      if (root.state === "unauthorized")
        return qsTr("The stored token was rejected. Paste a new one below.")
      if (root.site === "")
        return qsTr("Not connected.")
      return root.site + "\n" + root.account
    }
  }

  TextInput {
    id: hostInput

    width: parent.width
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    text: root.site !== "" ? root.site : "www.wrike.com"
    selectByMouse: true
    clip: true

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: hostInput.text === ""
      text: qsTr("Host: www.wrike.com, eu, or us2")
      color: root.faint
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  TextInput {
    id: tokenInput

    width: parent.width
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    echoMode: TextInput.Password
    selectByMouse: true
    clip: true

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: tokenInput.text === "" && !tokenInput.activeFocus
      text: qsTr("Permanent token")
      color: root.faint
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  ToggleRow {
    label: root.connecting ? qsTr("Connecting") : qsTr("Connect")
    hint: qsTr("Validates the token and stores it in the keyring")
    checked: false
    onActivated: {
      if (root.connecting)
        return
      root.connectRequested(hostInput.text, tokenInput.text)
      tokenInput.text = ""
    }
  }

  ToggleRow {
    visible: root.state === "ok" || root.site !== ""
    label: qsTr("Sign out")
    hint: qsTr("Removes the token from this machine")
    checked: false
    onActivated: root.disconnectRequested()
  }
}
