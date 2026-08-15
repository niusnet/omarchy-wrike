# Omarchy Wrike

Your Wrike work in the Omarchy bar, and a search box for everything else.

## What it shows

- **Your tasks**, split into what is in progress and what is still to do
- **This week**, with progress bars for time, finished work and overdue work
- **Search across the whole account**, by permalink id or by title

It is not a Wrike client. It answers two questions: what is on my plate right
now, and where is task X.

Wrike has no sprint. The week bars are the equivalent: the clock, the work
that belongs to this week, and how much of it is already late.

## Requirements

Omarchy Quattro with shell plugin support. Everything it needs at runtime,
`curl`, `jq` and `secret-tool`, is already part of an Omarchy install.

## Install

```bash
omarchy plugin add https://github.com/niusnet/omarchy-wrike.git --enable
cd ~/.config/omarchy/plugins/niusnet.wrike && ./omarchy-wrike-auth
```

The setup asks for your datacenter (`www.wrike.com`, `eu`, or `us2`) and a
permanent token, verifies them against Wrike before storing anything, and
prints the clicks to make on the token page. An empty token or Ctrl+C
cancels; nothing is stored.

### Update

```bash
omarchy plugin update niusnet.wrike
```

### Remove

```bash
omarchy plugin remove niusnet.wrike
```

Removing the plugin leaves the credential in your keyring. To take that with it:

```bash
./omarchy-wrike-auth --clear
```

## Credentials

The token lives in your system keyring, under `service=omarchy-wrike`. The
plugin reads it at request time and never copies, logs, caches, or writes it
anywhere. Nothing lands in `shell.json` or in a dotfile, and no credential is
ever typed into a bar popup.

Two details are deliberate rather than incidental:

- Credentials reach `curl` through a config file on a pipe, never as an
  argument, because anything in `argv` is readable by every process on the
  machine through `ps`.
- The plugin never calls `secret-tool search`, which prints the secret on
  stdout. It reads the credential with `lookup`, which returns only what was
  asked for.

Create the token in Wrike: **Profile → Apps & Integrations → API → Permanent
access token**. The token inherits your own permissions. This plugin only
reads tasks, spaces, and workflows.

## Controls

| Input | Action |
| --- | --- |
| Left click the icon | Open or close the panel |
| Right click the icon | Refresh |
| Click a row | Open the in-panel preview |
| `j` / `k` / arrows | Move through rows |
| `Enter` | Open the highlighted preview |
| `o` | Open the task in the browser |
| `y` | Copy the highlighted permalink id |
| `/` | Focus search |
| `r` | Refresh |
| `,` | Open the settings page |
| `Escape` | Close the preview, then the panel |

## Search

Typing filters the tasks already loaded straight away, and a query goes out to
Wrike after a short pause. Both sets of results land in one list.

```
109          finds the task whose permalink is open.htm?id=109
supplier     finds tasks with that word in the title
IEAAAAA…     finds a task by its API id
```

## Settings

Interval and row count are ordinary widget settings, editable wherever Omarchy
shows plugin settings.

Everything that depends on your Wrike lives in the panel's own settings page,
reachable with the gear or with `,`:

- **Spaces.** Untick the ones you do not care about. Ticked spaces feed your
  lists and bound your searches.
- **This week.** Time, tasks and overdue, independently. Untick them all to
  turn the section off, which also stops the plugin asking Wrike for it.
- **What counts as done.** The statuses in this week's plate, with the ones
  Wrike calls completed ticked to start with.

## How it groups your work

Nothing keys off a status name. Every Wrike account names its custom statuses
freely, so `In Review` is a label, never a signal.

The portable signals are:

- Wrike's status group: `Active`, `Completed`, `Cancelled`, `Deferred`
- Whether the task has already started: a Planned task whose start date is
  today or earlier, or a Milestone whose due date has arrived

Completed and cancelled work is dropped. Started active work is **in
progress**. Everything else assigned to you is **to do**.

## Local development

```bash
omarchy plugin validate .
tests/auth-test.sh && tests/helper-test.sh && tests/qml-source-test.sh
node --test tests/model.test.js
```

Run the helpers directly to see what the panel is given:

```bash
./omarchy-wrike-fetch --week | jq
./omarchy-wrike-fetch --search 109 | jq
```

QML changes need `omarchy restart shell`. Touching a file is not enough: the
shell keeps the compiled version in memory.

## How it works

`Service.qml` schedules `omarchy-wrike-fetch`, which owns every API call and
every credential access and prints one JSON document. `Panel.qml` assembles
small components and owns keyboard focus. `Model.js` holds the logic worth
testing and is exercised under `node --test` without a running shell.

## License

MIT
