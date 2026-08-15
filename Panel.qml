import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root

  moduleName: "niusnet.wrike"
  ipcTarget: "niusnet.wrike"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property string highlightedKey: ""
  property string confirmedKey: ""
  property string confirmation: ""
  property bool showSettings: false
  property bool showPreview: false

  readonly property var followedSpaces: wrike.followedSpaces
  readonly property string listFilter: Model.normalizeFilter(wrike.setting("listFilter", "all"))
  readonly property string groupBy: Model.normalizeGroupBy(wrike.setting("groupBy", "status"))

  property int weekTick: 0
  readonly property var weekBars: {
    weekTick
    return Model.weekBars(wrike.week, wrike.weekBarChoice, Date.now(), wrike.doneStatuses)
  }

  function setSetting(name, value) {
    var entry = { id: root.moduleName }
    for (var key in root.settings) {
      if (key !== "id")
        entry[key] = root.settings[key]
    }
    entry[name] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function allSpaceKeys() {
    var keys = []
    for (var i = 0; i < wrike.projects.length; i++)
      keys.push(String(wrike.projects[i].key || ""))
    return keys
  }

  function toggleDoneStatus(name) {
    setSetting("doneStatuses", Model.toggleDoneStatus(wrike.doneStatuses, name, Model.defaultDoneStatuses(wrike.week)))
  }

  function toggleWeekBar(id) {
    setSetting("weekBars", Model.toggleWeekBar(wrike.weekBarChoice, id))
    wrike.refresh()
  }

  function toggleSpace(key) {
    setSetting("followedSpaces", Model.toggleFollowedSpace(followedSpaces, key, allSpaceKeys()))
    wrike.refresh()
  }

  function setListFilter(id) {
    setSetting("listFilter", Model.normalizeFilter(id))
  }

  function setGroupBy(id) {
    setSetting("groupBy", Model.normalizeGroupBy(id))
  }

  readonly property bool searchActive: searchField.query.trim() !== ""
  readonly property string trimmedQuery: searchField.query.trim()
  readonly property bool searching: searchActive && wrike.answeredQuery !== trimmedQuery

  onSearchActiveChanged: highlightedKey = ""

  readonly property var visibleSections: {
    if (searchActive) {
      return Model.decorateSections([{
        title: qsTr("RESULTS"),
        tickets: Model.filterBySpace(
          Model.mergeSearchResults(Model.filterTickets(wrike.tickets, searchField.query), wrike.searchResults),
          root.followedSpaces)
      }], Date.now())
    }
    return Model.decorateSections(
      Model.listSections(wrike.tickets, root.groupBy, root.listFilter, wrike.maxDisplayedTickets, Date.now()),
      Date.now())
  }
  readonly property var visibleTickets: Model.flattenSections(visibleSections)

  function ticketAt(key) {
    for (var i = 0; i < visibleTickets.length; i++) {
      if (String(visibleTickets[i].key || "") === key)
        return visibleTickets[i]
    }
    return null
  }

  function moveHighlight(delta) {
    highlightedKey = Model.nextKey(visibleTickets, highlightedKey, delta)
  }

  function openPreview(key) {
    var ticket = ticketAt(key)
    if (!ticket)
      return
    showSettings = false
    showPreview = true
    wrike.preview(String(ticket.id || ticket.key || ""), ticket)
  }

  function openInBrowser(key) {
    var ticket = ticketAt(key) || wrike.previewTicket
    if (!ticket)
      return
    var url = String(ticket.url || "")
    if (url !== "")
      Qt.openUrlExternally(url)
  }

  function closePreview() {
    showPreview = false
    wrike.clearPreview()
  }

  function copyKey(key) {
    if (key === "")
      return
    clipboard.put(key)
    confirmedKey = key
    confirmation = qsTr("Copied ") + key
    confirmationTimer.restart()
  }

  function activateHighlighted() {
    if (highlightedKey !== "")
      openPreview(highlightedKey)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: {
    if (opened) {
      highlightedKey = ""
      showSettings = false
      closePreview()
      searchField.clear()
      wrike.clearSearch()
      wrike.refresh()
      if (panelFlick)
        panelFlick.contentY = 0
      Qt.callLater(function () { keyCatcher.forceActiveFocus() })
    }
  }

  Service {
    id: wrike

    settings: root.settings
  }

  IpcHandler {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { wrike.refresh(); return "ok" }
    function status(): string { return wrike.state }
    function search(query: string): string {
      root.open()
      root.showSettings = false
      searchField.setQuery(query)
      return "ok"
    }
    function settings(): string {
      root.open()
      root.showSettings = true
      return "ok"
    }
  }

  Timer {
    interval: 60000
    repeat: true
    running: root.opened
    onTriggered: root.weekTick++
  }

  Timer {
    id: confirmationTimer

    interval: 1500
    repeat: false
    onTriggered: {
      root.confirmedKey = ""
      root.confirmation = ""
    }
  }

  Clipboard { id: clipboard }

  BarIconButton {
    id: button

    anchors.fill: parent
    bar: root.bar
    text: "\uf0ae"
    active: wrike.needsAttention
    tooltipText: wrike.tooltip
    onPressed: function (buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton)
        wrike.refresh()
      else
        root.toggle()
    }
  }

  KeyboardPanel {
    id: panel

    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher

      anchors.fill: parent
      blocked: searchField.inputFocused || settingsView.inputFocused
      onMoveRequested: function (dx, dy) { if (dy !== 0) root.moveHighlight(dy) }
      onActivateRequested: root.activateHighlighted()
      onCloseRequested: {
        if (root.showPreview)
          root.closePreview()
        else
          root.close()
      }
      onTabRequested: Qt.callLater(function () { searchField.focusInput() })
      onTextKey: function (character) {
        var key = String(character || "").toLowerCase()
        if (key === "r")
          wrike.refresh()
        else if (key === "/")
          Qt.callLater(function () { searchField.focusInput() })
        else if (key === "y")
          root.copyKey(root.showPreview && wrike.previewTicket ? String(wrike.previewTicket.key || "") : root.highlightedKey)
        else if (key === "o")
          root.openInBrowser(root.highlightedKey)
        else if (key === ",")
          root.showSettings = !root.showSettings
      }

      Flickable {
        id: panelFlick

        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content

          width: panelFlick.width
          spacing: Style.space(14)

          PanelHeader {
            width: parent.width
            showingSettings: root.showSettings
            loading: wrike.loading
            hasData: wrike.hasData
            state: wrike.state
            message: wrike.message
            site: wrike.site
            inProgressCount: wrike.waitingCount
            todoCount: wrike.assignedCount
            foreground: root.foreground
            fontFamily: root.fontFamily
            onSettingsToggled: root.showSettings = !root.showSettings
          }

          WeekBars {
            width: parent.width
            visible: !root.showSettings && !root.showPreview
            week: wrike.week
            bars: root.weekBars
            timeLeft: Model.weekTimeLeft(wrike.week, Date.now())
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          WrikeSearchField {
            id: searchField

            width: parent.width
            visible: !root.showSettings && !root.showPreview
            busy: root.searching
            foreground: root.foreground
            fontFamily: root.fontFamily
            onQuerySubmitted: function (value) { wrike.search(String(value).trim()) }
            onMoveRequested: function (delta) { root.moveHighlight(delta) }
            onActivated: {
              if (root.highlightedKey !== "")
                root.openPreview(root.highlightedKey)
              else
                wrike.search(root.trimmedQuery)
            }
            onDismissed: {
              wrike.clearSearch()
              keyCatcher.forceActiveFocus()
            }
          }

          FilterBar {
            width: parent.width
            visible: !root.showSettings && !root.showPreview && !root.searchActive
            listFilter: root.listFilter
            groupBy: root.groupBy
            foreground: root.foreground
            fontFamily: root.fontFamily
            onFilterChosen: function (id) { root.setListFilter(id) }
            onGroupChosen: function (id) { root.setGroupBy(id) }
          }

          TaskPreview {
            width: parent.width
            visible: !root.showSettings && root.showPreview
            ticket: wrike.previewTicket
            loading: wrike.previewLoading
            foreground: root.foreground
            fontFamily: root.fontFamily
            onBackRequested: root.closePreview()
            onOpenRequested: root.openInBrowser(root.highlightedKey)
          }

          TaskSections {
            width: parent.width
            visible: !root.showSettings && !root.showPreview
            sections: root.visibleSections
            highlightedKey: root.highlightedKey
            confirmedKey: root.confirmedKey
            confirmation: root.confirmation
            foreground: root.foreground
            fontFamily: root.fontFamily
            onTicketActivated: function (key) { root.openPreview(key) }
            onTicketKeyRequested: function (key) { root.copyKey(key) }
          }

          StateNotice {
            width: parent.width
            visible: !root.showSettings && !root.showPreview && root.visibleTickets.length === 0
            state: {
              if (root.searching)
                return "searching"
              if (wrike.loading && !wrike.hasData)
                return "loading"
              return wrike.state
            }
            message: root.searching ? "" : wrike.message
            fetchedAt: wrike.fetchedAt
            hasStaleData: wrike.hasData && wrike.state !== "ok"
            searchActive: root.searchActive
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          SettingsView {
            id: settingsView

            width: parent.width
            visible: root.showSettings
            projects: wrike.projects
            followedSpaces: root.followedSpaces
            site: wrike.site
            account: wrike.account
            state: wrike.state
            connecting: wrike.connecting
            authMessage: wrike.authMessage
            foreground: root.foreground
            fontFamily: root.fontFamily
            week: wrike.week
            weekState: wrike.weekState
            weekBars: wrike.weekBarChoice
            dueCoverage: Model.dueCoverage(wrike.week)
            doneStatuses: wrike.doneStatuses.length > 0 ? wrike.doneStatuses : Model.defaultDoneStatuses(wrike.week)
            onSpaceToggled: function (key) { root.toggleSpace(key) }
            onWeekBarToggled: function (id) { root.toggleWeekBar(id) }
            onDoneStatusToggled: function (name) { root.toggleDoneStatus(name) }
            onConnectRequested: function (host, token) { wrike.connectAccount(host, token) }
            onDisconnectRequested: wrike.disconnectAccount()
            onAllSpacesCleared: {
              root.setSetting("followedSpaces", [])
              wrike.refresh()
            }
          }
        }
      }
    }
  }
}
