const test = require('node:test')
const assert = require('node:assert')
const Model = require('../Model.js')

const TASKS = [
  { key: '101', summary: 'Refresh card limit', status: 'In Progress', statusCategory: 'indeterminate', projectKey: 'IEAAAADEMO000001', projectName: 'Demo', updated: '2026-08-14T06:24:20Z' },
  { key: '102', summary: 'Retry failed supplier payments', status: 'Review', statusCategory: 'indeterminate', projectKey: 'IEAAAADEMO000001', projectName: 'Demo', updated: '2026-08-12T11:02:00Z' },
  { key: '103', summary: 'Freeze lock files', status: 'New', statusCategory: 'new', projectKey: 'IEAAAADEMO000001', projectName: 'Demo', updated: '2026-06-12T16:29:09Z' },
  { key: '104', summary: 'Duplicate group members', status: 'Deferred', statusCategory: 'new', projectKey: 'IEAAAAOPS0000002', projectName: 'Ops', updated: '2026-05-02T09:15:00Z' },
  { key: '105', summary: 'Traveler names', status: 'Completed', statusCategory: 'done', projectKey: 'IEAAAADEMO000001', projectName: 'Demo', updated: '2026-02-09T14:27:44Z' }
]

test('groupTickets puts started work in waiting and the rest in assigned', () => {
  const groups = Model.groupTickets(TASKS)
  assert.deepEqual(groups.waiting.map(t => t.key), ['101', '102'])
  assert.deepEqual(groups.assigned.map(t => t.key), ['103', '104'])
})

test('groupTickets drops the done category', () => {
  const groups = Model.groupTickets(TASKS)
  const keys = groups.waiting.concat(groups.assigned).map(t => t.key)
  assert.equal(keys.indexOf('105'), -1)
})

test('groupTickets keys off the category, never the status name', () => {
  const groups = Model.groupTickets([
    { key: '1', status: 'Peer Review', statusCategory: 'indeterminate' },
    { key: '2', status: 'In Progress', statusCategory: 'new' }
  ])
  assert.deepEqual(groups.waiting.map(t => t.key), ['1'])
  assert.deepEqual(groups.assigned.map(t => t.key), ['2'])
})

test('groupTickets treats an unknown category as assigned rather than hiding it', () => {
  const groups = Model.groupTickets([{ key: '1', statusCategory: 'something-new' }])
  assert.deepEqual(groups.assigned.map(t => t.key), ['1'])
})

test('groupTickets tolerates null and empty input', () => {
  assert.deepEqual(Model.groupTickets(null), { waiting: [], assigned: [] })
  assert.deepEqual(Model.groupTickets([]), { waiting: [], assigned: [] })
})

test('relativeTime renders each scale', () => {
  const now = Date.parse('2026-08-14T12:00:00Z')
  assert.equal(Model.relativeTime('2026-08-14T11:59:30Z', now), 'just now')
  assert.equal(Model.relativeTime('2026-08-14T11:45:00Z', now), '15m ago')
  assert.equal(Model.relativeTime('2026-08-14T09:00:00Z', now), '3h ago')
  assert.equal(Model.relativeTime('2026-08-12T12:00:00Z', now), '2d ago')
  assert.equal(Model.relativeTime('2026-06-14T12:00:00Z', now), '2mo ago')
})

test('relativeTime returns an empty string for unusable input', () => {
  const now = Date.parse('2026-08-14T12:00:00Z')
  assert.equal(Model.relativeTime('', now), '')
  assert.equal(Model.relativeTime('not a date', now), '')
  assert.equal(Model.relativeTime(null, now), '')
})

test('relativeTime never renders a negative age', () => {
  const now = Date.parse('2026-08-14T12:00:00Z')
  assert.equal(Model.relativeTime('2026-08-14T13:00:00Z', now), 'just now')
})

test('decorateRows stamps a relative age without touching the input', () => {
  const now = Date.parse('2026-08-14T12:00:00Z')
  const rows = [{ key: '101', updated: '2026-08-14T09:00:00Z' }]
  const decorated = Model.decorateRows(rows, now)
  assert.equal(decorated[0].age, '3h ago')
  assert.equal(rows[0].age, undefined)
})

const ROWS = [{ key: '101' }, { key: '102' }, { key: '103' }]

test('nextKey walks the list and stops at the ends', () => {
  assert.equal(Model.nextKey(ROWS, '101', 1), '102')
  assert.equal(Model.nextKey(ROWS, '102', -1), '101')
  assert.equal(Model.nextKey(ROWS, '103', 1), '103')
  assert.equal(Model.nextKey(ROWS, '101', -1), '101')
})

test('nextKey lands on an end when nothing is selected', () => {
  assert.equal(Model.nextKey(ROWS, '', 1), '101')
  assert.equal(Model.nextKey(ROWS, '', -1), '103')
})

test('nextKey tolerates an empty list', () => {
  assert.equal(Model.nextKey([], '101', 1), '')
  assert.equal(Model.nextKey(null, '101', 1), '')
})

test('filterTickets matches on key and on title, case insensitively', () => {
  assert.deepEqual(Model.filterTickets(TASKS, '102').map(t => t.key), ['102'])
  assert.deepEqual(Model.filterTickets(TASKS, 'LOCK').map(t => t.key), ['103'])
  assert.deepEqual(Model.filterTickets(TASKS, 'supplier').map(t => t.key), ['102'])
})

test('filterTickets returns everything for an empty query', () => {
  assert.equal(Model.filterTickets(TASKS, '').length, TASKS.length)
  assert.equal(Model.filterTickets(TASKS, '   ').length, TASKS.length)
})

test('mergeSearchResults keeps local results first and marks remote ones', () => {
  const local = [{ key: '102' }]
  const remote = [{ key: '102' }, { key: '999' }]
  const merged = Model.mergeSearchResults(local, remote)
  assert.deepEqual(merged.map(t => t.key), ['102', '999'])
  assert.equal(merged[0].remote, false)
  assert.equal(merged[1].remote, true)
})

test('mergeSearchResults does not mutate its inputs', () => {
  const local = [{ key: '102' }]
  const remote = [{ key: '999' }]
  Model.mergeSearchResults(local, remote)
  assert.equal(local[0].remote, undefined)
  assert.equal(remote[0].remote, undefined)
})

const DEMO = 'IEAAAADEMO000001'
const OPS = 'IEAAAAOPS0000002'
const HUB = 'IEAAAAHUB0000003'
const ADMIN = 'IEAAAAADMIN00004'
const ALL = [ADMIN, DEMO, HUB, OPS]

test('spaceList keeps original case and accepts a comma separated string', () => {
  assert.deepEqual(Model.spaceList([DEMO, HUB]), [DEMO, HUB])
  assert.deepEqual(Model.spaceList(DEMO + ',' + HUB), [DEMO, HUB])
  assert.deepEqual(Model.spaceList(DEMO + ', ' + HUB), [DEMO, HUB])
})

test('spaceList drops blanks and case-insensitive duplicates', () => {
  assert.deepEqual(Model.spaceList([DEMO, '', DEMO.toLowerCase(), HUB]), [DEMO, HUB])
  assert.deepEqual(Model.spaceList(null), [])
  assert.deepEqual(Model.spaceList(''), [])
})

test('unticking one box from the default keeps every other space', () => {
  assert.deepEqual(Model.toggleFollowedSpace([], ADMIN, ALL), [DEMO, HUB, OPS])
})

test('ticking and unticking a box from a real selection', () => {
  assert.deepEqual(Model.toggleFollowedSpace([DEMO], HUB, ALL), [DEMO, HUB])
  assert.deepEqual(Model.toggleFollowedSpace([DEMO, HUB], DEMO, ALL), [HUB])
})

test('unticking the last box falls back to showing everything', () => {
  assert.deepEqual(Model.toggleFollowedSpace([DEMO], DEMO, ALL), [])
})

test('ticking the last missing box is stored as no filter', () => {
  assert.deepEqual(Model.toggleFollowedSpace([DEMO, HUB, OPS], ADMIN, ALL), [])
})

test('toggleFollowedSpace matches space ids case insensitively', () => {
  assert.deepEqual(Model.toggleFollowedSpace([DEMO], HUB.toLowerCase(), ALL), [DEMO, HUB.toLowerCase()])
  assert.deepEqual(Model.toggleFollowedSpace([DEMO], '', ALL), [DEMO])
})

test('idList normalises to one convention', () => {
  assert.deepEqual(Model.idList(['TIME', 'TASKS', 'overdue']), ['time', 'tasks', 'overdue'])
  assert.deepEqual(Model.idList('time, tasks'), ['time', 'tasks'])
  assert.deepEqual(Model.idList(null), [])
})

test('toggleWeekBar adds, removes, and can empty the list', () => {
  assert.deepEqual(Model.toggleWeekBar(['time'], 'overdue'), ['time', 'overdue'])
  assert.deepEqual(Model.toggleWeekBar(['time', 'overdue'], 'time'), ['overdue'])
  assert.deepEqual(Model.toggleWeekBar(['time'], 'time'), [])
})

test('filterBySpace drops spaces that are not followed', () => {
  const results = [
    { key: '1', projectKey: ADMIN },
    { key: '2', projectKey: DEMO },
    { key: '3', projectKey: HUB }
  ]
  assert.deepEqual(Model.filterBySpace(results, [DEMO]).map(t => t.key), ['2'])
  assert.deepEqual(Model.filterBySpace(results, [DEMO, HUB]).map(t => t.key), ['2', '3'])
})

test('filterBySpace leaves the list alone when nothing is followed', () => {
  const results = [{ key: '1', projectKey: DEMO }, { key: '2', projectKey: OPS }]
  assert.deepEqual(Model.filterBySpace(results, []).map(t => t.key), ['1', '2'])
  assert.deepEqual(Model.filterBySpace(null, [DEMO]), [])
})

const WEEK = {
  name: 'This week',
  startDate: '2026-08-10T00:00:00.000Z',
  endDate: '2026-08-17T00:00:00.000Z',
  total: 10,
  dated: 8,
  overdue: 2,
  statuses: [
    { name: 'Completed', category: 'done', count: 4 },
    { name: 'Active', category: 'indeterminate', count: 5 },
    { name: 'Deferred', category: 'new', count: 1 }
  ]
}

const MIDWEEK = Date.parse('2026-08-13T12:00:00.000Z')

test('weekBars reports time and work side by side', () => {
  const bars = Model.weekBars(WEEK, ['time', 'tasks'], MIDWEEK)
  assert.deepEqual(bars.map(b => b.id), ['time', 'tasks'])
  assert.equal(bars[0].percent, 50)
  assert.equal(bars[1].percent, 40)
  assert.equal(bars[1].detail, '4/10')
})

test('weekBars can show overdue too', () => {
  const bars = Model.weekBars(WEEK, ['time', 'tasks', 'overdue'], MIDWEEK)
  assert.deepEqual(bars.map(b => b.id), ['time', 'tasks', 'overdue'])
  assert.equal(bars[2].percent, 20)
  assert.equal(bars[2].detail, '2/10')
})

test('weekTotals falls back to what Wrike calls completed', () => {
  const totals = Model.weekTotals(WEEK, [])
  assert.equal(totals.total, 10)
  assert.equal(totals.done, 4)
  assert.equal(totals.overdue, 2)
})

test("weekTotals honours the team's own definition of done", () => {
  const totals = Model.weekTotals(WEEK, ['Completed', 'Deferred'])
  assert.equal(totals.done, 5)
})

test('defaultDoneStatuses starts from what Wrike calls completed', () => {
  assert.deepEqual(Model.defaultDoneStatuses(WEEK), ['Completed'])
})

test('weekBars shows nothing when nothing is asked for', () => {
  assert.deepEqual(Model.weekBars(WEEK, [], MIDWEEK), [])
  assert.deepEqual(Model.weekBars(null, ['time'], MIDWEEK), [])
})

test('weekBars never reports negative or overrun time', () => {
  const before = Date.parse('2026-08-01T00:00:00.000Z')
  const after = Date.parse('2026-08-20T00:00:00.000Z')
  assert.equal(Model.weekBars(WEEK, ['time'], before)[0].percent, 0)
  assert.equal(Model.weekBars(WEEK, ['time'], after)[0].percent, 100)
})

test('weekBars marks where the clock stands on each work bar', () => {
  const bars = Model.weekBars(WEEK, ['time', 'tasks'], MIDWEEK)
  assert.equal(bars[0].mark, null)
  assert.equal(bars[1].mark, 50)
})

test('weekTimeLeft is the headline figure, not a bar detail', () => {
  assert.equal(Model.weekTimeLeft(WEEK, MIDWEEK), '4d left')
  assert.equal(Model.weekTimeLeft(WEEK, Date.parse('2026-08-20T00:00:00.000Z')), 'ended')
  assert.equal(Model.weekTimeLeft(null, MIDWEEK), '')
})

test('toggleDoneStatus starts from what is drawn, not from nothing', () => {
  assert.deepEqual(Model.toggleDoneStatus([], 'Completed', ['Completed', 'Cancelled']), ['Cancelled'])
})

test('dueCoverage says how much of the week is dated', () => {
  assert.equal(Model.dueCoverage(WEEK), '8 of 10 tasks have a due date')
  const full = Object.assign({}, WEEK, { dated: 10 })
  assert.equal(Model.dueCoverage(full), 'every task has a due date')
  assert.equal(Model.dueCoverage(null), '')
})

test('limit caps the list and ignores a broken setting', () => {
  assert.equal(Model.limit(TASKS, 2).length, 2)
  assert.equal(Model.limit(TASKS, 0).length, TASKS.length)
  assert.equal(Model.limit(TASKS, -5).length, TASKS.length)
  assert.deepEqual(Model.limit(null, 5), [])
})

test('stripHtml turns markup into readable text', () => {
  assert.equal(Model.stripHtml('<p>Hello<br>world</p>'), 'Hello\nworld')
  assert.equal(Model.stripHtml('A &amp; B &lt;C&gt;'), 'A & B <C>')
  assert.equal(Model.stripHtml(''), '')
})

test('applyListFilter keeps only the asked group', () => {
  const now = Date.parse('2026-08-14T12:00:00Z')
  const withDue = TASKS.map(t => Object.assign({}, t, {
    due: t.key === '102' ? '2026-08-08' : t.key === '103' ? '2026-08-20' : ''
  }))
  assert.deepEqual(Model.applyListFilter(withDue, 'progress', now).map(t => t.key), ['101', '102'])
  assert.deepEqual(Model.applyListFilter(withDue, 'todo', now).map(t => t.key), ['103', '104'])
  assert.deepEqual(Model.applyListFilter(withDue, 'overdue', now).map(t => t.key), ['102'])
  assert.equal(Model.applyListFilter(withDue, 'all', now).length, withDue.length)
})

test('groupBySpace clusters by space name, not by the inner project', () => {
  const groups = Model.groupBySpace([
    { key: '2', spaceName: 'Ops', projectName: 'Admin' },
    { key: '1', spaceName: 'Demo', projectName: 'Website Redesign' },
    { key: '3', spaceName: 'Demo', projectName: 'Website Redesign' }
  ])
  assert.deepEqual(groups.map(g => g.title), ['Demo', 'Ops'])
  assert.deepEqual(groups[0].tickets.map(t => t.key), ['1', '3'])
})

test('newestComments sorts newest first and pages them', () => {
  const page = Model.newestComments([
    { id: 'a', created: '2026-08-10T10:00:00Z', text: 'old' },
    { id: 'c', created: '2026-08-14T10:00:00Z', text: 'new' },
    { id: 'b', created: '2026-08-12T10:00:00Z', text: 'mid' }
  ], 2)
  assert.deepEqual(page.items.map(c => c.id), ['c', 'b'])
  assert.equal(page.remaining, 1)
})

test('formatEffortMinutes and breadcrumbText', () => {
  assert.equal(Model.formatEffortMinutes(90), '1h 30m')
  assert.equal(Model.formatEffortMinutes(60), '1h')
  assert.equal(Model.breadcrumbText({
    breadcrumb: [{ title: 'Demo' }, { title: 'Website' }]
  }), 'Demo / Website')
})

test('listSections can group by status or by space', () => {
  const byStatus = Model.listSections(TASKS, 'status', 'all', 25)
  assert.deepEqual(byStatus.map(s => s.title), ['IN PROGRESS', 'TO DO'])
  const bySpace = Model.listSections(TASKS, 'space', 'progress', 25)
  assert.deepEqual(bySpace.map(s => s.title), ['Demo'])
  assert.deepEqual(bySpace[0].tickets.map(t => t.key), ['101', '102'])
})

test('flattenSections walks sections in display order', () => {
  const flat = Model.flattenSections(Model.listSections(TASKS, 'status', 'all', 25))
  assert.deepEqual(flat.map(t => t.key), ['101', '102', '103', '104'])
})
