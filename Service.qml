import QtQuick
import Quickshell.Io
import "Model.js" as Model

// Wrike data service. The helper owns every API call and every credential
// access; this item schedules it and exposes one stable model to the panel.
//
// A failed refresh never discards a good payload. Tasks and their timestamp
// are replaced only when a run comes back ok.
Item {
  id: root

  property var settings: ({})

  property bool loading: false
  property string state: "loading"
  property string message: qsTr("Loading Wrike")
  property string site: ""
  property string account: ""
  property string fetchedAt: ""
  property var tickets: []
  property var projects: []
  property var week: null
  property string weekState: "off"

  property var searchResults: []
  property string searchQuery: ""
  property string answeredQuery: ""

  property bool refreshQueued: false
  property string _stdout: ""
  property string _searchStdout: ""

  readonly property var groups: Model.groupTickets(tickets)
  readonly property int waitingCount: groups.waiting.length
  readonly property int assignedCount: groups.assigned.length
  readonly property bool needsAttention: state !== "ok" && state !== "loading"
  readonly property string tooltip: {
    if (state === "loading")
      return qsTr("Wrike")
    if (state !== "ok")
      return message !== "" ? message : qsTr("Wrike is unavailable")
    return waitingCount + qsTr(" in progress, ") + assignedCount + qsTr(" to do")
  }
  readonly property int maxDisplayedTickets: intSetting("maxDisplayedTickets", 25, 5, 100)
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 900, 60, 3600)
  readonly property bool connected: state === "ok"
  readonly property bool hasData: tickets.length > 0

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, minimum, maximum) {
    var value = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(value))
      value = fallback
    return Math.max(minimum, Math.min(maximum, value))
  }

  function helperPath() {
    return Qt.resolvedUrl("omarchy-wrike-fetch").toString().replace(/^file:\/\//, "")
  }

  readonly property var followedSpaces: Model.spaceList(setting("followedSpaces", []))
  readonly property var weekBarChoice: Model.idList(setting("weekBars", ["time", "tasks"]))
  readonly property bool wantWeek: weekBarChoice.length > 0
  readonly property var doneStatuses: {
    var stored = setting("doneStatuses", [])
    return Array.isArray(stored) ? stored : Model.spaceList(stored)
  }

  function dashboardCommand() {
    var command = [helperPath(), "--max", String(maxDisplayedTickets * 2)]
    var followed = followedSpaces
    if (followed.length > 0)
      command.push("--spaces", followed.join(","))
    if (wantWeek)
      command.push("--week")
    return command
  }

  function refresh() {
    if (fetchProcess.running) {
      refreshQueued = true
      return
    }
    refreshQueued = false
    loading = true
    _stdout = ""
    fetchProcess.command = dashboardCommand()
    fetchProcess.running = true
  }

  function apply(raw) {
    var data
    try {
      data = JSON.parse(String(raw || ""))
    } catch (error) {
      state = "error"
      message = qsTr("Wrike returned a response this widget could not read.")
      return
    }

    state = String(data.state || "error")
    message = String(data.message || "")

    if (String(data.site || "") !== "")
      site = String(data.site)
    if (String(data.account || "") !== "")
      account = String(data.account)

    if (state !== "ok")
      return

    tickets = Array.isArray(data.tickets) ? data.tickets : []
    projects = Array.isArray(data.projects) ? data.projects : []
    week = data.week || null
    weekState = String(data.weekState || "off")
    fetchedAt = String(data.generatedAt || "")
  }

  function search(query) {
    searchQuery = String(query || "")
    if (searchQuery.trim() === "") {
      clearSearch()
      return
    }
    if (searchProcess.running)
      searchProcess.running = false
    _searchStdout = ""
    var command = [helperPath(), "--search", searchQuery]
    if (followedSpaces.length > 0)
      command.push("--spaces", followedSpaces.join(","))
    searchProcess.command = command
    searchProcess.running = true
  }

  function clearSearch() {
    searchQuery = ""
    searchResults = []
    answeredQuery = ""
    if (searchProcess.running)
      searchProcess.running = false
  }

  function applySearch(raw, query) {
    try {
      var data = JSON.parse(String(raw || ""))
      searchResults = (String(data.state || "") === "ok" && Array.isArray(data.tickets)) ? data.tickets : []
    } catch (error) {
      searchResults = []
    }
    answeredQuery = String(query || "")
  }

  visible: false

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: fetchProcess

    running: false
    command: []
    onExited: function (exitCode) {
      root.loading = false
      var output = String(collector.text || root._stdout || "")
      if (output.trim() !== "") {
        root.apply(output)
      } else {
        root.state = "error"
        root.message = qsTr("The Wrike helper produced no output.")
      }
      if (root.refreshQueued) {
        root.refreshQueued = false
        Qt.callLater(root.refresh)
      }
    }

    stdout: StdioCollector {
      id: collector

      waitForEnd: true
      onStreamFinished: root._stdout = text
    }
  }

  Process {
    id: searchProcess

    running: false
    command: []
    onExited: function (exitCode) {
      root.applySearch(String(searchCollector.text || root._searchStdout || ""), root.searchQuery)
    }

    stdout: StdioCollector {
      id: searchCollector

      waitForEnd: true
      onStreamFinished: root._searchStdout = text
    }
  }
}
