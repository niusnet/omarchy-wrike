import QtQuick
import qs.Commons
import "Model.js" as Model

Column {
  id: root

  property var ticket: null
  property bool loading: false
  property bool posting: false
  property string actionMessage: ""
  property int commentsLimit: 5
  property color foreground: "white"
  property string fontFamily: ""

  signal backRequested()
  signal openRequested()
  signal moreCommentsRequested()
  signal commentRequested(string text)
  signal timeRequested(string hours, string note)

  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.9)
  readonly property bool inputFocused: commentInput.activeFocus || hoursInput.activeFocus || timeNoteInput.activeFocus
  readonly property string bodyText: {
    if (!ticket)
      return ""
    var full = Model.stripHtml(ticket.description)
    if (full !== "")
      return full
    return Model.stripHtml(ticket.brief)
  }
  readonly property var commentPage: Model.newestComments(ticket ? ticket.comments : [], commentsLimit)
  readonly property string effortText: ticket ? Model.formatEffortMinutes(ticket.effortMinutes) : ""
  readonly property string pathText: ticket ? Model.breadcrumbText(ticket) : ""

  width: parent ? parent.width : 0
  spacing: Style.space(10)

  Row {
    width: parent.width
    spacing: Style.space(8)

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
    visible: root.pathText !== ""
    text: root.pathText
    color: root.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
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
      if (String(ticket.importance || "") !== "")
        parts.push(String(ticket.importance))
      if (String(ticket.start || "") !== "")
        parts.push(qsTr("start ") + String(ticket.start).slice(0, 10))
      if (String(ticket.due || "") !== "")
        parts.push(qsTr("due ") + String(ticket.due).slice(0, 10))
      if (root.effortText !== "")
        parts.push(qsTr("effort ") + root.effortText)
      return parts.join("  ·  ")
    }
  }

  Text {
    width: parent.width
    visible: ticket && ticket.hasAttachments
    text: {
      var count = ticket && ticket.attachmentCount ? Number(ticket.attachmentCount) : (ticket && ticket.attachments ? ticket.attachments.length : 0)
      if (count === 1)
        return qsTr("1 attachment")
      return count + qsTr(" attachments")
    }
    color: root.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Repeater {
    model: ticket && ticket.attachments ? ticket.attachments : []

    Text {
      required property var modelData
      width: root.width
      text: String(modelData.name || "Attachment")
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      TapHandler {
        onTapped: {
          var url = String(modelData.url || "")
          if (url !== "")
            Qt.openUrlExternally(url)
        }
      }
    }
  }

  Text {
    width: parent.width
    text: qsTr("DESCRIPTION")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1
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
  }

  Text {
    width: parent.width
    text: qsTr("LOG TIME")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1
  }

  Row {
    width: parent.width
    spacing: Style.space(4)

    TextInput {
      id: hoursInput
      width: Style.space(36)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      text: "1"
    }

    TextInput {
      id: timeNoteInput
      width: parent.width - hoursInput.width - Style.space(20)
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: timeNoteInput.text === "" && !timeNoteInput.activeFocus
        text: qsTr("Note (optional)")
        color: root.faint
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Text {
    text: root.posting ? qsTr("Saving") : qsTr("Log hours")
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    TapHandler {
      onTapped: {
        if (!root.posting)
          root.timeRequested(hoursInput.text, timeNoteInput.text)
      }
    }
  }

  Text {
    width: parent.width
    text: qsTr("COMMENTS")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    font.letterSpacing: 1
  }

  Repeater {
    model: root.commentPage.items

    Column {
      required property var modelData
      width: root.width
      spacing: Style.space(1)

      Text {
        width: parent.width
        text: String(modelData.author || "") + "  ·  " + Model.relativeTime(modelData.created, Date.now())
        color: root.faint
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        width: parent.width
        text: Model.stripHtml(modelData.text)
        color: root.muted
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }
    }
  }

  Text {
    width: parent.width
    visible: root.commentPage.items.length === 0
    text: qsTr("No comments yet.")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    visible: root.commentPage.remaining > 0
    text: qsTr("Load more comments") + " (" + root.commentPage.remaining + ")"
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    TapHandler { onTapped: root.moreCommentsRequested() }
  }

  TextInput {
    id: commentInput
    width: parent.width
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: TextInput.Wrap
    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: commentInput.text === "" && !commentInput.activeFocus
      text: qsTr("Write a comment")
      color: root.faint
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Text {
    text: root.posting ? qsTr("Sending") : qsTr("Send comment")
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    font.bold: true
    TapHandler {
      onTapped: {
        if (root.posting || commentInput.text.trim() === "")
          return
        root.commentRequested(commentInput.text)
        commentInput.text = ""
      }
    }
  }

  Text {
    width: parent.width
    visible: root.actionMessage !== ""
    text: root.actionMessage
    color: root.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
