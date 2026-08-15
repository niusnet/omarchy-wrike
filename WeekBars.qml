import QtQuick
import qs.Commons

Column {
  id: root

  property var week: null
  property var bars: []
  property string timeLeft: ""
  property color foreground: "white"
  property string fontFamily: ""

  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 2.1)
  readonly property bool hasWeek: week !== null && week !== undefined
  readonly property real labelWidth: labelMetrics.width + Style.space(6)
  readonly property real detailWidth: detailMetrics.width + Style.space(4)

  TextMetrics {
    id: labelMetrics

    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    text: "overdue"
  }

  TextMetrics {
    id: detailMetrics

    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    text: "000/000"
  }

  width: parent ? parent.width : 0
  spacing: Style.space(5)
  visible: hasWeek && bars.length > 0

  Item {
    width: parent.width
    height: Math.max(weekName.height, timeLabel.height)

    Text {
      id: weekName

      anchors.left: parent.left
      anchors.right: timeLabel.left
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      text: root.hasWeek ? String(root.week.name || "") : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: true
      elide: Text.ElideRight
    }

    Text {
      id: timeLabel

      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.timeLeft
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(4)

    Repeater {
      model: root.bars

      Item {
        id: barRow

        required property var modelData

        readonly property bool isReference: modelData.id === "time"

        width: parent ? parent.width : 0
        height: Math.max(barLabel.height, track.height)

        Text {
          id: barLabel

          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: root.labelWidth
          text: barRow.modelData.label
          color: root.faint
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        Rectangle {
          id: track

          anchors.left: barLabel.right
          anchors.right: parent.right
          anchors.rightMargin: barRow.modelData.detail !== "" ? root.detailWidth : 0
          anchors.verticalCenter: parent.verticalCenter
          height: Style.space(4)
          radius: height / 2
          color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1)

          Rectangle {
            width: parent.width * Math.max(0, Math.min(100, barRow.modelData.percent)) / 100
            height: parent.height
            radius: parent.radius
            color: barRow.isReference
              ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.3)
              : Color.accent

            Behavior on width {
              NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
          }

          Rectangle {
            visible: barRow.modelData.mark !== null && barRow.modelData.mark !== undefined
            x: parent.width * Math.max(0, Math.min(100, barRow.modelData.mark || 0)) / 100 - width / 2
            width: Math.max(2, Style.spacing.hairline * 2)
            height: parent.height + Style.space(5)
            anchors.verticalCenter: parent.verticalCenter
            color: root.foreground
          }
        }

        Text {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          visible: barRow.modelData.detail !== ""
          text: barRow.modelData.detail
          color: root.muted
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignRight
        }
      }
    }
  }
}
