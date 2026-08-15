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

  property var week: null
  property string weekState: "off"
  property var weekBars: []
  property string dueCoverage: ""
  property var doneStatuses: []

  signal spaceToggled(string key)
  signal allSpacesCleared()
  signal weekBarToggled(string id)
  signal doneStatusToggled(string name)

  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.9)
  readonly property bool followingAll: !followedSpaces || followedSpaces.length === 0

  function countsAsDone(name) {
    for (var i = 0; i < doneStatuses.length; i++) {
      if (String(doneStatuses[i]).toLowerCase() === String(name).toLowerCase())
        return true
    }
    return false
  }

  function showsBar(id) {
    return weekBars.indexOf(String(id).toLowerCase()) !== -1
  }

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

  SectionTitle { text: qsTr("THIS WEEK") }

  Text {
    width: parent.width
    text: qsTr("Which progress bars to show above your tasks. Untick them all to turn the section off and stop asking Wrike for it.")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  ToggleRow {
    label: qsTr("Time")
    hint: qsTr("How much of the week has elapsed")
    checked: root.showsBar("time")
    onActivated: root.weekBarToggled("time")
  }

  ToggleRow {
    label: qsTr("Tasks")
    hint: root.dueCoverage !== "" ? root.dueCoverage : qsTr("Tasks finished out of this week's plate")
    checked: root.showsBar("tasks")
    onActivated: root.weekBarToggled("tasks")
  }

  ToggleRow {
    label: qsTr("Overdue")
    hint: qsTr("Assigned work whose due date already passed")
    checked: root.showsBar("overdue")
    onActivated: root.weekBarToggled("overdue")
  }

  Text {
    width: parent.width
    visible: root.weekBars.length > 0
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    text: {
      if (root.weekState === "unavailable")
        return qsTr("Wrike did not answer for this week.")
      return ""
    }
  }

  SectionTitle {
    text: qsTr("COUNTS AS DONE")
    visible: root.week !== null && root.weekBars.length > 0
  }

  Text {
    width: parent.width
    visible: root.week !== null && root.weekBars.length > 0
    text: qsTr("The statuses in this week's plate. Tick the ones your team treats as finished.")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Repeater {
    model: (root.week !== null && root.weekBars.length > 0) ? (root.week.statuses || []) : []

    ToggleRow {
      required property var modelData

      label: String(modelData.name || "")
      hint: modelData.count + (modelData.count === 1 ? qsTr(" task") : qsTr(" tasks"))
      checked: root.countsAsDone(String(modelData.name || ""))
      onActivated: root.doneStatusToggled(String(modelData.name || ""))
    }
  }

  SectionTitle { text: qsTr("CONNECTION") }

  Text {
    width: parent.width
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
    text: {
      if (root.state === "unconfigured")
        return qsTr("Not connected. Run omarchy-wrike-auth in a terminal.")
      if (root.state === "unauthorized")
        return qsTr("The stored token was rejected. Run omarchy-wrike-auth again.")
      if (root.site === "")
        return qsTr("Not connected.")
      return root.site + "\n" + root.account
    }
  }
}
