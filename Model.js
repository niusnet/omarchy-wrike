// Pure logic for the Wrike widget: grouping, searching, and formatting.
//
// Everything here is Qt-free so it can be unit tested under node
// (tests/model.test.js). The QML side owns rendering and scheduling; this file
// owns what the payload means.
//
// The single rule worth repeating: nothing keys off a status name. Every Wrike
// account names its custom statuses freely, so "In Review" is a label, never a
// signal. The portable signals are Wrike's status group (Active, Completed,
// Cancelled, Deferred) and whether a task has already started.

var CATEGORY_WAITING = "indeterminate"
var CATEGORY_DONE = "done"

var MINUTE = 60
var HOUR = 3600
var DAY = 86400
var MONTH = 2592000
var MS_PER_DAY = 86400000

function asArray(value) {
  return Array.isArray(value) ? value : []
}

function text(value) {
  return value === undefined || value === null ? "" : String(value)
}

// Splits tasks into what the user has to act on and what is merely assigned.
//
// An unrecognised category lands in `assigned` rather than being dropped. A
// Wrike account that invents a group is a reason to show work in a slightly
// wrong section, never a reason to hide it.
function groupTickets(tickets) {
  var waiting = []
  var assigned = []
  var list = asArray(tickets)

  for (var i = 0; i < list.length; i++) {
    var ticket = list[i]
    var category = text(ticket && ticket.statusCategory)
    if (category === CATEGORY_DONE)
      continue
    if (category === CATEGORY_WAITING)
      waiting.push(ticket)
    else
      assigned.push(ticket)
  }

  return { waiting: waiting, assigned: assigned }
}

function relativeTime(value, nowMs) {
  var then = Date.parse(text(value))
  if (!isFinite(then))
    return ""

  var now = isFinite(nowMs) ? nowMs : Date.now()
  var seconds = Math.floor((now - then) / 1000)
  if (seconds < MINUTE)
    return "just now"
  if (seconds < HOUR)
    return Math.floor(seconds / MINUTE) + "m ago"
  if (seconds < DAY)
    return Math.floor(seconds / HOUR) + "h ago"
  if (seconds < MONTH)
    return Math.floor(seconds / DAY) + "d ago"
  return Math.floor(seconds / MONTH) + "mo ago"
}

// Stamps a relative age onto each row.
function decorateRows(rows, nowMs) {
  var list = asArray(rows)
  var now = isFinite(nowMs) ? nowMs : Date.now()
  var decorated = []
  for (var i = 0; i < list.length; i++) {
    var copy = {}
    for (var name in list[i]) {
      if (Object.prototype.hasOwnProperty.call(list[i], name))
        copy[name] = list[i][name]
    }
    copy.age = relativeTime(list[i].updated, now)
    decorated.push(copy)
  }
  return decorated
}

// The key the cursor lands on after a move.
function nextKey(tickets, currentKey, delta) {
  var list = asArray(tickets)
  if (list.length === 0)
    return ""

  var index = -1
  for (var i = 0; i < list.length; i++) {
    if (text(list[i].key) === text(currentKey)) {
      index = i
      break
    }
  }

  if (index === -1)
    index = delta > 0 ? 0 : list.length - 1
  else
    index = Math.max(0, Math.min(list.length - 1, index + delta))

  return text(list[index].key)
}

// Matches a query against the permalink id and the title. This runs on every
// keystroke against tasks already in memory, which is what makes the search
// feel instant while the remote query is still in flight.
function filterTickets(tickets, query) {
  var list = asArray(tickets)
  var needle = text(query).trim().toLowerCase()
  if (needle === "")
    return list.slice()

  var matches = []
  for (var i = 0; i < list.length; i++) {
    var ticket = list[i]
    var key = text(ticket && ticket.key).toLowerCase()
    var summary = text(ticket && ticket.summary).toLowerCase()
    if (key.indexOf(needle) !== -1 || summary.indexOf(needle) !== -1)
      matches.push(ticket)
  }
  return matches
}

function mergeSearchResults(local, remote) {
  var merged = []
  var seen = {}
  var i
  var localList = asArray(local)
  var remoteList = asArray(remote)

  for (i = 0; i < localList.length; i++) {
    var here = localList[i]
    var localKey = text(here && here.key)
    if (localKey !== "" && seen[localKey])
      continue
    seen[localKey] = true
    merged.push(withRemoteFlag(here, false))
  }

  for (i = 0; i < remoteList.length; i++) {
    var there = remoteList[i]
    var remoteKey = text(there && there.key)
    if (remoteKey !== "" && seen[remoteKey])
      continue
    seen[remoteKey] = true
    merged.push(withRemoteFlag(there, true))
  }

  return merged
}

function withRemoteFlag(ticket, remote) {
  var copy = {}
  for (var name in ticket) {
    if (Object.prototype.hasOwnProperty.call(ticket, name))
      copy[name] = ticket[name]
  }
  copy.remote = remote
  return copy
}

function idList(value) {
  var raw = []
  if (Array.isArray(value))
    raw = value
  else if (text(value) !== "")
    raw = text(value).split(",")

  var ids = []
  for (var i = 0; i < raw.length; i++) {
    var id = text(raw[i]).trim().toLowerCase()
    if (id !== "" && ids.indexOf(id) === -1)
      ids.push(id)
  }
  return ids
}

function toggleWeekBar(current, id) {
  var chosen = idList(current)
  var wanted = text(id).trim().toLowerCase()
  if (wanted === "")
    return chosen

  var at = chosen.indexOf(wanted)
  if (at === -1)
    chosen.push(wanted)
  else
    chosen.splice(at, 1)
  return chosen
}

// Normalises the followed-spaces setting into a list of space ids.
//
// Space ids are opaque Wrike identifiers and must keep their original case.
// The settings pane stores a list; `omarchy bar set` may store a comma
// separated string. Both have to mean the same thing.
function spaceList(value) {
  var raw = []
  if (Array.isArray(value))
    raw = value
  else if (text(value) !== "")
    raw = text(value).split(",")

  var ids = []
  var seen = {}
  for (var i = 0; i < raw.length; i++) {
    var id = text(raw[i]).trim()
    var lowered = id.toLowerCase()
    if (id !== "" && !seen[lowered]) {
      seen[lowered] = true
      ids.push(id)
    }
  }
  return ids
}

function sameId(left, right) {
  return text(left).toLowerCase() === text(right).toLowerCase()
}

function toggleFollowedSpace(followed, key, allKeys) {
  var current = spaceList(followed)
  var all = spaceList(allKeys)
  var wanted = text(key).trim()
  if (wanted === "")
    return current

  var next
  var i
  if (current.length === 0) {
    next = []
    for (i = 0; i < all.length; i++) {
      if (!sameId(all[i], wanted))
        next.push(all[i])
    }
  } else {
    next = current.slice()
    var at = -1
    for (i = 0; i < next.length; i++) {
      if (sameId(next[i], wanted)) {
        at = i
        break
      }
    }
    if (at === -1)
      next.push(wanted)
    else
      next.splice(at, 1)
  }

  if (next.length === 0 || (all.length > 0 && next.length === all.length))
    return []
  return next
}

function toggleDoneStatus(current, name, defaults) {
  var selection = asArray(current)
  if (selection.length === 0)
    selection = asArray(defaults)

  var wanted = text(name)
  if (wanted === "")
    return selection.slice()

  var lowered = wanted.toLowerCase()
  var next = []
  var found = false
  for (var i = 0; i < selection.length; i++) {
    if (text(selection[i]).toLowerCase() === lowered)
      found = true
    else
      next.push(selection[i])
  }
  if (!found)
    next.push(wanted)
  return next
}

function filterBySpace(tickets, followed) {
  var list = asArray(tickets)
  var keys = asArray(followed)
  if (keys.length === 0 || list.length === 0)
    return list.slice()

  var lowered = []
  var i
  for (i = 0; i < keys.length; i++)
    lowered.push(text(keys[i]).toLowerCase())

  var kept = []
  for (i = 0; i < list.length; i++) {
    if (lowered.indexOf(text(list[i] && list[i].projectKey).toLowerCase()) !== -1)
      kept.push(list[i])
  }
  return kept
}

var WEEK_BAR_TIME = "time"
var WEEK_BAR_TASKS = "tasks"
var WEEK_BAR_OVERDUE = "overdue"

function weekTotals(week, doneStatuses) {
  var totals = { total: 0, done: 0, overdue: 0 }
  if (!week)
    return totals

  totals.overdue = Number(week.overdue) || 0

  var statuses = asArray(week.statuses)
  var chosen = []
  var explicit = asArray(doneStatuses)
  for (var c = 0; c < explicit.length; c++)
    chosen.push(text(explicit[c]).toLowerCase())

  for (var i = 0; i < statuses.length; i++) {
    var entry = statuses[i]
    var count = Number(entry.count) || 0
    var finished = chosen.length > 0
      ? chosen.indexOf(text(entry.name).toLowerCase()) !== -1
      : text(entry.category) === CATEGORY_DONE

    totals.total += count
    if (finished)
      totals.done += count
  }
  return totals
}

function defaultDoneStatuses(week) {
  var names = []
  var statuses = asArray(week && week.statuses)
  for (var i = 0; i < statuses.length; i++) {
    if (text(statuses[i].category) === CATEGORY_DONE)
      names.push(text(statuses[i].name))
  }
  return names
}

function weekBars(week, wanted, nowMs, doneStatuses) {
  if (!week)
    return []

  var chosen = idList(wanted)
  var bars = []
  var now = isFinite(nowMs) ? nowMs : Date.now()
  var totals = weekTotals(week, doneStatuses)
  var elapsedPercent = timePercent(week, now)

  if (chosen.indexOf(WEEK_BAR_TIME) !== -1 && elapsedPercent !== null) {
    bars.push({
      id: WEEK_BAR_TIME,
      label: "time",
      percent: elapsedPercent,
      detail: "",
      mark: null
    })
  }

  if (chosen.indexOf(WEEK_BAR_TASKS) !== -1) {
    var ticketPercent = totals.total > 0 ? Math.round((totals.done / totals.total) * 100) : 0
    bars.push({
      id: WEEK_BAR_TASKS,
      label: "tasks",
      percent: ticketPercent,
      detail: totals.done + "/" + totals.total,
      mark: elapsedPercent
    })
  }

  if (chosen.indexOf(WEEK_BAR_OVERDUE) !== -1) {
    var overduePercent = totals.total > 0 ? Math.round((totals.overdue / totals.total) * 100) : 0
    bars.push({
      id: WEEK_BAR_OVERDUE,
      label: "overdue",
      percent: overduePercent,
      detail: totals.overdue + "/" + totals.total,
      mark: elapsedPercent
    })
  }

  return bars
}

function timePercent(span, nowMs) {
  var start = Date.parse(text(span && span.startDate))
  var end = Date.parse(text(span && span.endDate))
  if (!isFinite(start) || !isFinite(end) || end <= start)
    return null
  var elapsed = Math.min(Math.max(nowMs - start, 0), end - start)
  return Math.round((elapsed / (end - start)) * 100)
}

function weekTimeLeft(week, nowMs) {
  var end = Date.parse(text(week && week.endDate))
  if (!isFinite(end))
    return ""
  return daysLeftLabel(end, isFinite(nowMs) ? nowMs : Date.now())
}

function daysLeftLabel(endMs, nowMs) {
  var remaining = endMs - nowMs
  if (remaining <= 0)
    return "ended"
  var days = Math.ceil(remaining / MS_PER_DAY)
  if (days === 1)
    return "1d left"
  return days + "d left"
}

function dueCoverage(week) {
  if (!week)
    return ""
  var total = Number(week.total) || 0
  var dated = Number(week.dated) || 0
  if (total === 0)
    return ""
  if (dated === total)
    return "every task has a due date"
  return dated + " of " + total + " tasks have a due date"
}

function limit(tickets, max) {
  var list = asArray(tickets)
  var cap = Number(max)
  if (!isFinite(cap) || cap < 1)
    return list.slice()
  return list.slice(0, cap)
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    groupTickets: groupTickets,
    relativeTime: relativeTime,
    decorateRows: decorateRows,
    nextKey: nextKey,
    filterTickets: filterTickets,
    mergeSearchResults: mergeSearchResults,
    filterBySpace: filterBySpace,
    weekBars: weekBars,
    weekTotals: weekTotals,
    weekTimeLeft: weekTimeLeft,
    defaultDoneStatuses: defaultDoneStatuses,
    toggleDoneStatus: toggleDoneStatus,
    dueCoverage: dueCoverage,
    spaceList: spaceList,
    idList: idList,
    toggleWeekBar: toggleWeekBar,
    toggleFollowedSpace: toggleFollowedSpace,
    limit: limit
  }
}
