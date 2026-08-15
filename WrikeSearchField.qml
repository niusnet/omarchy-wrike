import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string query: ""
  property bool busy: false
  property color foreground: "white"
  property string fontFamily: ""
  property int debounceMs: 300

  signal querySubmitted(string value)
  signal dismissed()
  signal moveRequested(int delta)
  signal activated()

  readonly property bool working: busy
  readonly property alias inputFocused: input.activeFocus
  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.9)

  function focusInput() {
    input.forceActiveFocus()
  }

  function setQuery(value) {
    input.text = String(value || "")
    input.forceActiveFocus()
  }

  function clear() {
    debounce.stop()
    input.text = ""
    root.query = ""
  }

  function submitOrActivate() {
    debounce.stop()
    root.activated()
  }

  width: parent ? parent.width : 0
  height: input.implicitHeight + Style.space(6)
  radius: Style.cornerRadius
  color: Qt.rgba(foreground.r, foreground.g, foreground.b, input.activeFocus ? 0.1 : 0.05)

  Timer {
    id: debounce

    interval: root.debounceMs
    repeat: false
    onTriggered: root.querySubmitted(root.query)
  }

  Text {
    id: prompt

    anchors.left: parent.left
    anchors.leftMargin: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
    text: root.working ? "\uf110" : "\uf002"
    color: root.working ? root.muted : root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall

    RotationAnimation on rotation {
      running: root.working
      from: 0
      to: 360
      duration: 900
      loops: Animation.Infinite
      onStopped: prompt.rotation = 0
    }
  }

  Rectangle {
    id: shortcutHint

    anchors.right: parent.right
    anchors.rightMargin: Style.space(3)
    anchors.verticalCenter: parent.verticalCenter
    visible: !input.activeFocus && input.text === ""
    width: hintLabel.width + Style.space(4)
    height: hintLabel.height + Style.space(2)
    radius: Style.cornerRadius
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

    Text {
      id: hintLabel

      anchors.centerIn: parent
      text: "/"
      color: root.faint
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  TextInput {
    id: input

    anchors.left: prompt.right
    anchors.right: shortcutHint.visible ? shortcutHint.left : parent.right
    anchors.leftMargin: Style.space(3)
    anchors.rightMargin: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    selectByMouse: true
    clip: true

    onTextChanged: {
      root.query = text
      if (text.trim() === "") {
        debounce.stop()
        root.querySubmitted("")
      } else {
        debounce.restart()
      }
    }

    Keys.onUpPressed: root.moveRequested(-1)
    Keys.onDownPressed: root.moveRequested(1)
    Keys.onReturnPressed: root.submitOrActivate()
    Keys.onEnterPressed: root.submitOrActivate()
    Keys.onEscapePressed: function (event) {
      if (input.text !== "") {
        input.text = ""
        event.accepted = true
        return
      }
      root.dismissed()
      event.accepted = true
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: input.text === "" && !input.activeFocus
      text: qsTr("Search any task by id or title")
      color: root.faint
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }
}
