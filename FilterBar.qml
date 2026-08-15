import QtQuick
import qs.Commons

Column {
  id: root

  property string listFilter: "all"
  property string groupBy: "status"
  property color foreground: "white"
  property string fontFamily: ""

  signal filterChosen(string id)
  signal groupChosen(string id)

  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.9)

  width: parent ? parent.width : 0
  spacing: Style.space(4)

  component Chip: Rectangle {
    id: chip

    property string label: ""
    property bool checked: false

    signal activated()

    width: chipLabel.width + Style.space(6)
    height: chipLabel.height + Style.space(3)
    radius: Style.cornerRadius
    color: chip.checked
      ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
      : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)

    HoverHandler { id: chipHover }
    TapHandler { onTapped: chip.activated() }

    Text {
      id: chipLabel

      anchors.centerIn: parent
      text: chip.label
      color: chip.checked ? root.foreground : root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Flow {
    width: parent.width
    spacing: Style.space(3)

    Chip { label: qsTr("All"); checked: root.listFilter === "all"; onActivated: root.filterChosen("all") }
    Chip { label: qsTr("In progress"); checked: root.listFilter === "progress"; onActivated: root.filterChosen("progress") }
    Chip { label: qsTr("To do"); checked: root.listFilter === "todo"; onActivated: root.filterChosen("todo") }
    Chip { label: qsTr("Overdue"); checked: root.listFilter === "overdue"; onActivated: root.filterChosen("overdue") }
  }

  Flow {
    width: parent.width
    spacing: Style.space(3)

    Chip { label: qsTr("By status"); checked: root.groupBy === "status"; onActivated: root.groupChosen("status") }
    Chip { label: qsTr("By space"); checked: root.groupBy === "space"; onActivated: root.groupChosen("space") }
  }
}
