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

  property var previewTicket: null
  property bool previewLoading: false
  property bool attachmentsLoading: false
  property bool previewPosting: false
  property string previewKey: ""
  property string previewAction: ""
  property int commentsLimit: 10

  property bool connecting: false
  property string authMessage: ""

  property bool refreshQueued: false
  property string _stdout: ""
  property string _searchStdout: ""
  property string _authStdout: ""
  property string _authStderr: ""
  property string _previewStdout: ""
  property string _previewPayload: ""
  property string _authPayload: ""

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

  function authPath() {
    return Qt.resolvedUrl("omarchy-wrike-auth").toString().replace(/^file:\/\//, "")
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

    if (state !== "ok") {
      if (state === "unconfigured") {
        tickets = []
        projects = []
        week = null
        weekState = "off"
      }
      return
    }

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

  function connectAccount(host, token) {
    if (String(token || "").trim() === "") {
      authMessage = qsTr("Paste a token first.")
      return
    }
    if (authProcess.running)
      authProcess.running = false
    connecting = true
    authMessage = qsTr("Connecting")
    _authStdout = ""
    _authPayload = JSON.stringify({ host: String(host || ""), token: String(token || "") })
    authProcess.command = [authPath(), "--connect"]
    authProcess.running = true
  }

  function disconnectAccount() {
    if (authProcess.running)
      authProcess.running = false
    connecting = true
    authMessage = qsTr("Signing out")
    _authStdout = ""
    _authPayload = ""
    authProcess.command = [authPath(), "--disconnect"]
    authProcess.running = true
  }

  function preview(taskId, fallback) {
    previewKey = String(taskId || "")
    previewTicket = fallback || null
    commentsLimit = 10
    if (previewKey === "")
      return
    if (previewProcess.running)
      previewProcess.running = false
    previewLoading = true
    _previewStdout = ""
    _previewPayload = ""
    previewProcess.stdinEnabled = false
    previewProcess.command = [helperPath(), "--task", previewKey]
    previewProcess.running = true
  }

  function showMoreComments() {
    commentsLimit += 10
  }

  function loadAttachments() {
    if (previewKey === "" || attachmentsLoading)
      return
    if (previewTicket && Array.isArray(previewTicket.attachments) && previewTicket.attachments.length > 0 && previewTicket.attachments[0].url)
      return
    if (previewProcess.running)
      previewProcess.running = false
    attachmentsLoading = true
    _previewStdout = ""
    _previewPayload = ""
    previewProcess.stdinEnabled = false
    previewProcess.command = [helperPath(), "--attachments", previewKey]
    previewProcess.running = true
  }

  function postComment(text) {
    if (previewKey === "" || String(text || "").trim() === "")
      return
    runPreviewAction("--comment", JSON.stringify({ text: String(text) }))
  }

  function logTime(hours, note) {
    if (previewKey === "" || String(hours || "").trim() === "")
      return
    var today = new Date()
    var month = today.getMonth() + 1
    var day = today.getDate()
    var date = today.getFullYear() + "-" + (month < 10 ? "0" : "") + month + "-" + (day < 10 ? "0" : "") + day
    runPreviewAction("--timelog", JSON.stringify({
      hours: String(hours),
      trackedDate: date,
      comment: String(note || "")
    }))
  }

  function runPreviewAction(flag, payload) {
    if (previewProcess.running)
      previewProcess.running = false
    previewPosting = true
    previewAction = qsTr("Saving")
    _previewStdout = ""
    _previewPayload = payload
    previewProcess.command = [helperPath(), flag, previewKey]
    previewProcess.stdinEnabled = payload !== ""
    previewProcess.running = true
  }

  function clearPreview() {
    previewKey = ""
    previewTicket = null
    previewLoading = false
    attachmentsLoading = false
    previewPosting = false
    previewAction = ""
    commentsLimit = 10
    if (previewProcess.running)
      previewProcess.running = false
  }

  function applyPreview(raw) {
    previewLoading = false
    attachmentsLoading = false
    previewPosting = false
    try {
      var data = JSON.parse(String(raw || ""))
      if (String(data.state || "") === "ok" && Array.isArray(data.tickets) && data.tickets.length > 0) {
        previewTicket = mergePreview(previewTicket, data.tickets[0])
        previewAction = ""
      } else {
        previewAction = String(data.message || qsTr("Could not update the task."))
      }
    } catch (error) {
      previewAction = qsTr("Could not read the task response.")
    }
  }

  function mergePreview(current, incoming) {
    if (!current)
      return incoming
    var merged = {}
    var name
    for (name in current) {
      if (Object.prototype.hasOwnProperty.call(current, name))
        merged[name] = current[name]
    }
    for (name in incoming) {
      if (!Object.prototype.hasOwnProperty.call(incoming, name))
        continue
      var value = incoming[name]
      if (Array.isArray(value) && value.length === 0 && Array.isArray(merged[name]) && merged[name].length > 0)
        continue
      if ((value === "" || value === null || value === undefined) && merged[name])
        continue
      merged[name] = value
    }
    return merged
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

  Process {
    id: authProcess

    running: false
    command: []
    stdinEnabled: true
    onStarted: {
      if (root._authPayload !== "")
        write(root._authPayload + "\n")
      root._authPayload = ""
    }
    onExited: function (exitCode) {
      root.connecting = false
      var output = String(authCollector.text || root._authStdout || "").trim()
      var err = String(authErr.text || root._authStderr || "").trim()
      root.authMessage = output !== "" ? output : err
      if (exitCode === 0)
        root.refresh()
      else if (root.authMessage === "")
        root.authMessage = qsTr("Could not update the Wrike session.")
    }

    stdout: StdioCollector {
      id: authCollector

      waitForEnd: true
      onStreamFinished: root._authStdout = text
    }

    stderr: StdioCollector {
      id: authErr

      waitForEnd: true
      onStreamFinished: root._authStderr = text
    }
  }

  Process {
    id: previewProcess

    running: false
    command: []
    stdinEnabled: false
    onStarted: {
      if (root._previewPayload !== "")
        write(root._previewPayload + "\n")
      root._previewPayload = ""
    }
    onExited: function (exitCode) {
      root.applyPreview(String(previewCollector.text || root._previewStdout || ""))
    }

    stdout: StdioCollector {
      id: previewCollector

      waitForEnd: true
      onStreamFinished: root._previewStdout = text
    }
  }
}
