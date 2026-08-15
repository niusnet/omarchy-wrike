import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

Column {
  id: root

  property var ticket: null
  property bool loading: false
  property bool attachmentsLoading: false
  property bool posting: false
  property string actionMessage: ""
  property int commentsLimit: 10
  property string previewTab: "details"
  readonly property string ticketId: ticket ? String(ticket.id || ticket.key || "") : ""
  property color foreground: "white"
  property string fontFamily: ""

  signal backRequested()
  signal openRequested()
  signal moreCommentsRequested()
  signal attachmentsRequested()
  signal commentRequested(string text)
  signal timeRequested(string hours, string note)

  readonly property color muted: Qt.darker(foreground, 1.5)
  readonly property color faint: Qt.darker(foreground, 1.9)
  readonly property bool inputFocused: commentField.activeFocus || hoursField.activeFocus || noteField.activeFocus
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
  readonly property int attachmentTotal: {
    if (!ticket)
      return 0
    var count = Number(ticket.attachmentCount || 0)
    if ((!count || count === 0) && ticket.attachments)
      count = ticket.attachments.length
    return count || 0
  }

  onTicketIdChanged: root.previewTab = "details"
  onPreviewTabChanged: {
    if (root.previewTab === "attachments")
      root.attachmentsRequested()
  }

  width: parent ? parent.width : 0
  spacing: Style.space(12)

  Rectangle {
    width: parent.width
    visible: root.loading
    height: loadLabel.implicitHeight + Style.space(8)
    radius: Style.cornerRadius
    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

    Text {
      id: loadLabel
      anchors.centerIn: parent
      text: qsTr("Loading from Wrike…")
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  component SectionLabel: PanelSectionHeader {
    width: root.width
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  component MetaRow: Row {
    property string label: ""
    property string value: ""
    width: root.width
    spacing: Style.space(8)
    visible: value !== "" && root.previewTab === "details"

    Text {
      width: Style.space(72)
      text: label
      color: root.faint
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      width: parent.width - Style.space(80)
      text: value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }
  }

  Row {
    width: parent.width
    spacing: Style.space(8)

    Button {
      text: qsTr("Back to list")
      foreground: root.foreground
      fontFamily: root.fontFamily
      bordered: true
      onClicked: root.backRequested()
    }

    Button {
      text: qsTr("Open in Wrike")
      foreground: root.foreground
      accent: Color.accent
      fontFamily: root.fontFamily
      active: true
      onClicked: root.openRequested()
    }
  }

  Column {
    width: parent.width
    spacing: Style.space(4)

    Text {
      width: parent.width
      visible: ticket && String(ticket.key || "") !== ""
      text: ticket ? "#" + String(ticket.key) : ""
      color: root.faint
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Text {
      width: parent.width
      text: ticket ? String(ticket.summary || "") : ""
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
      wrapMode: Text.WordWrap
    }

    Text {
      width: parent.width
      visible: root.pathText !== ""
      text: root.pathText
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }
  }

  Row {
    width: parent.width
    spacing: Style.space(8)

    Button {
      text: qsTr("Details")
      foreground: root.foreground
      fontFamily: root.fontFamily
      bordered: true
      active: root.previewTab === "details"
      onClicked: root.previewTab = "details"
    }

    Button {
      text: qsTr("Attachments") + (root.attachmentTotal > 0 ? " · " + root.attachmentTotal : "")
      foreground: root.foreground
      fontFamily: root.fontFamily
      bordered: true
      active: root.previewTab === "attachments"
      onClicked: root.previewTab = "attachments"
    }
  }

  PanelSeparator { width: parent.width; visible: root.previewTab === "details" }

  SectionLabel { visible: root.previewTab === "details"; text: qsTr("DETAILS") }

  MetaRow { label: qsTr("Space"); value: ticket ? String(ticket.spaceName || "") : "" }
  MetaRow { label: qsTr("Project"); value: ticket && String(ticket.projectName || "") !== String(ticket.spaceName || "") ? String(ticket.projectName || "") : "" }
  MetaRow { label: qsTr("Folder"); value: ticket && String(ticket.folderName || "") !== String(ticket.projectName || "") && String(ticket.folderName || "") !== String(ticket.spaceName || "") ? String(ticket.folderName || "") : "" }
  MetaRow { label: qsTr("Status"); value: ticket ? String(ticket.status || "") : "" }
  MetaRow { label: qsTr("Type"); value: ticket ? String(ticket.type || "") : "" }
  MetaRow { label: qsTr("Importance"); value: ticket ? String(ticket.importance || "") : "" }
  MetaRow { label: qsTr("Start"); value: ticket && ticket.start ? String(ticket.start).slice(0, 10) : "" }
  MetaRow { label: qsTr("Due"); value: ticket && ticket.due ? String(ticket.due).slice(0, 10) : "" }
  MetaRow { visible: root.previewTab === "details"; label: qsTr("Effort"); value: root.effortText }

  Column {
    width: parent.width
    spacing: Style.space(6)
    visible: root.previewTab === "attachments"

    SectionLabel { text: qsTr("ATTACHMENTS") }

    Text {
      width: parent.width
      visible: root.attachmentsLoading
      text: qsTr("Loading attachments…")
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      width: parent.width
      visible: !root.attachmentsLoading && root.attachmentTotal === 0
      text: qsTr("No attachments on this task.")
      color: root.faint
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Repeater {
      model: ticket && ticket.attachments ? ticket.attachments : []

      Button {
        required property var modelData
        width: root.width
        text: String(modelData.name || qsTr("Attachment"))
        foreground: root.foreground
        fontFamily: root.fontFamily
        leftAlign: true
        bordered: true
        onClicked: {
          var url = String(modelData.url || "")
          if (url !== "")
            Qt.openUrlExternally(url)
        }
      }
    }
  }

  PanelSeparator { width: parent.width; visible: root.previewTab === "details" }

  SectionLabel { visible: root.previewTab === "details"; text: qsTr("DESCRIPTION") }

  Text {
    width: parent.width
    visible: root.previewTab === "details" && root.loading && root.bodyText === ""
    text: qsTr("Loading description")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Flickable {
    width: parent.width
    height: Math.min(Style.space(220), Math.max(Style.space(80), descText.implicitHeight + Style.space(8)))
    contentWidth: width
    contentHeight: descText.implicitHeight + Style.space(8)
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    visible: root.previewTab === "details" && root.bodyText !== ""
    interactive: contentHeight > height

    Text {
      id: descText
      width: parent.width
      text: root.bodyText
      color: root.muted
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }
  }

  Text {
    width: parent.width
    visible: root.previewTab === "details" && root.bodyText !== "" && descText.implicitHeight > Style.space(220)
    text: qsTr("Scroll to read the full description")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    width: parent.width
    visible: root.previewTab === "details" && !root.loading && root.bodyText === ""
    text: qsTr("No description on this task.")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  PanelSeparator { width: parent.width; visible: root.previewTab === "details" }

  SectionLabel { visible: root.previewTab === "details"; text: qsTr("LOG TIME") }

  Row {
    width: parent.width
    visible: root.previewTab === "details"
    spacing: Style.space(8)

    TextField {
      id: hoursField
      width: Style.space(64)
      foreground: root.foreground
      font.family: root.fontFamily
      placeholderText: qsTr("Hours")
      text: "1"
    }

    TextField {
      id: noteField
      width: parent.width - hoursField.width - logButton.width - Style.space(20)
      foreground: root.foreground
      font.family: root.fontFamily
      placeholderText: qsTr("Note (optional)")
    }

    Button {
      id: logButton
      text: root.posting ? qsTr("Saving") : qsTr("Log time")
      foreground: root.foreground
      fontFamily: root.fontFamily
      bordered: true
      onClicked: {
        if (!root.posting)
          root.timeRequested(hoursField.text, noteField.text)
      }
    }
  }

  PanelSeparator { width: parent.width; visible: root.previewTab === "details" }

  SectionLabel { visible: root.previewTab === "details"; text: qsTr("COMMENTS") }

  Repeater {
    model: root.previewTab === "details" ? root.commentPage.items : []

    Rectangle {
      required property var modelData
      width: root.width
      height: commentBody.implicitHeight + Style.space(10)
      radius: Style.cornerRadius
      color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
      border.width: 1
      border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)

      Column {
        id: commentBody
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(8)
        anchors.rightMargin: Style.space(8)
        spacing: Style.space(3)

        Text {
          width: parent.width
          text: String(modelData.author || qsTr("Someone")) + "  ·  " + Model.formatCommentDate(modelData.created)
          color: root.faint
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
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
  }

  Text {
    width: parent.width
    visible: root.previewTab === "details" && !root.loading && root.commentPage.items.length === 0
    text: qsTr("No comments yet.")
    color: root.faint
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Button {
    visible: root.previewTab === "details"
    enabled: root.commentPage.remaining > 0
    text: root.commentPage.remaining > 0
      ? qsTr("Load 10 more") + " · " + root.commentPage.remaining + qsTr(" left")
      : qsTr("All comments loaded")
    foreground: root.foreground
    fontFamily: root.fontFamily
    bordered: true
    onClicked: {
      if (root.commentPage.remaining > 0)
        root.moreCommentsRequested()
    }
  }

  TextField {
    id: commentField
    visible: root.previewTab === "details"
    width: parent.width
    foreground: root.foreground
    font.family: root.fontFamily
    placeholderText: qsTr("Write a comment")
  }

  Button {
    visible: root.previewTab === "details"
    text: root.posting ? qsTr("Sending") : qsTr("Send comment")
    foreground: root.foreground
    fontFamily: root.fontFamily
    active: true
    onClicked: {
      if (root.posting || commentField.text.trim() === "")
        return
      root.commentRequested(commentField.text)
      commentField.text = ""
    }
  }

  Text {
    width: parent.width
    visible: root.previewTab === "details" && root.actionMessage !== ""
    text: root.actionMessage
    color: root.muted
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
