#!/usr/bin/env bash
# Tests for omarchy-wrike-fetch.
#
# The helper is the only part of the plugin that talks to Wrike, so its contract
# is what the QML side is written against: exactly one JSON document on stdout,
# and exit code zero for every failure the user can actually encounter.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HELPER="$ROOT/omarchy-wrike-fetch"
FIXTURES="$ROOT/tests/fixtures"

TOKEN="TESTTOKENvalue1234567890"
EMAIL="probe@example.com"
HOST="www.wrike.com"
BASE="https://www.wrike.com/api/v4"
USER_ID="KUAAAAAA"

failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

assert_jq() {
  local filter="$1" payload="$2" label="$3"
  jq -e "$filter" >/dev/null 2>&1 <<<"$payload" || fail "$label"
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  [[ $haystack == *"$needle"* ]] || fail "$label (expected to find \"$needle\")"
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  [[ $haystack != *"$needle"* ]] || fail "$label (unexpectedly found \"$needle\")"
}

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT

export STUB_DIR="$sandbox/state"
export FIXTURE_DIR="$FIXTURES"
mkdir -p "$STUB_DIR" "$sandbox/bin"

for tool in bash cat rm mktemp jq date; do
  path=$(command -v "$tool" 2>/dev/null) && ln -sf "$path" "$sandbox/bin/$(basename "$tool")"
done

cat >"$sandbox/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >>"$STUB_DIR/calls"
config=""
output=""
url=""
query_params=()
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[i]}" in
  --config) config="${args[i + 1]}" ;;
  --output) output="${args[i + 1]}" ;;
  --url) url="${args[i + 1]}" ;;
  --data-urlencode) query_params+=("${args[i + 1]}") ;;
  esac
done
if [[ -n $config && -r $config ]]; then
  cat "$config" >>"$STUB_DIR/creds"
fi
printf '%s %s\n' "$url" "${query_params[*]-}" >>"$STUB_DIR/urls"

if [[ ${CURL_STUB_FAIL:-0} == 1 ]]; then
  echo "curl: (6) Could not resolve host" >&2
  exit 6
fi

code="${CURL_STUB_CODE:-200}"
params="${query_params[*]-}"
if [[ $url == *"/workflows"* ]]; then
  code="${WORKFLOWS_STUB_CODE:-$code}"
  [[ -n $output ]] && cat "$FIXTURE_DIR/workflows.json" >"$output"
elif [[ $url == *"/spaces/"*"/tasks"* ]]; then
  [[ -n $output ]] && cat "$FIXTURE_DIR/tasks.json" >"$output"
elif [[ $url == *"/spaces"* ]]; then
  code="${SPACES_STUB_CODE:-$code}"
  [[ -n $output ]] && cat "$FIXTURE_DIR/spaces.json" >"$output"
elif [[ $url == *"/folders"* ]]; then
  [[ -n $output ]] && cat "$FIXTURE_DIR/folders.json" >"$output"
elif [[ $url == *"/comments"* ]]; then
  [[ -n $output ]] && cat "$FIXTURE_DIR/comments.json" >"$output"
elif [[ $url == *"/attachments"* ]]; then
  [[ -n $output ]] && cat "$FIXTURE_DIR/attachments.json" >"$output"
elif [[ $url == *"/contacts"* ]]; then
  [[ -n $output ]] && printf '%s' '{"data":[{"id":"KUAAAAAA","firstName":"Test","lastName":"User"}]}' >"$output"
elif [[ $url == *"/ids"* ]]; then
  [[ -n $output ]] && cat "$FIXTURE_DIR/ids.json" >"$output"
elif [[ $url == *"/tasks/"* ]]; then
  [[ -n $output ]] && cat "$FIXTURE_DIR/task-by-id.json" >"$output"
elif [[ $params == *title=* ]]; then
  [[ -n $output ]] && cat "$FIXTURE_DIR/search-title.json" >"$output"
elif [[ $params == *Completed* || $params == *completedDate* ]]; then
  [[ -n $output ]] && cat "$FIXTURE_DIR/completed.json" >"$output"
else
  [[ -n $output ]] && cat "$FIXTURE_DIR/tasks.json" >"$output"
fi
printf '%s' "$code"
STUB

cat >"$sandbox/bin/secret-tool" <<'STUB'
#!/usr/bin/env bash
printf 'secret-tool %s\n' "$*" >>"$STUB_DIR/calls"
case "${1:-}" in
lookup)
  if [[ ${KEYRING_STUB_BROKEN:-0} == 1 ]]; then
    echo "secret-tool: Cannot autolaunch D-Bus without X11 \$DISPLAY" >&2
    exit 1
  fi
  [[ -s $STUB_DIR/vault ]] || exit 1
  cat "$STUB_DIR/vault"
  ;;
search)
  echo "search must never be called" >&2
  exit 3
  ;;
*)
  exit 2
  ;;
esac
STUB

chmod +x "$sandbox/bin/curl" "$sandbox/bin/secret-tool"

store_credential() {
  jq -nc --arg host "$HOST" --arg account "$EMAIL" --arg base "$BASE" \
    --arg token "$TOKEN" --arg userId "$USER_ID" \
    '{host: $host, account: $account, base: $base, token: $token, userId: $userId}' \
    >"$STUB_DIR/vault"
}

reset_state() {
  rm -f "$STUB_DIR/calls" "$STUB_DIR/creds" "$STUB_DIR/urls" "$STUB_DIR/vault"
  : >"$STUB_DIR/calls"
  : >"$STUB_DIR/creds"
  : >"$STUB_DIR/urls"
}

run_helper() {
  PATH="$sandbox/bin" WRIKE_NOW="2026-08-13T12:00:00Z" "$HELPER" "$@" 2>/dev/null
}

bash -n "$HELPER" || fail "helper does not parse"
PATH="$sandbox/bin" "$HELPER" --help >/dev/null || fail "--help failed"

reset_state
store_credential
payload=$(run_helper) || fail "helper exited non zero on success"

assert_jq '.' "$payload" "the payload is not valid JSON"
assert_jq '.state == "ok"' "$payload" "state is not ok"
assert_jq '.schema == 1' "$payload" "schema version missing"
assert_jq '.mode == "dashboard"' "$payload" "mode is not dashboard"
assert_jq '.site == "'"$HOST"'"' "$payload" "host missing from the payload"
assert_jq '.account == "'"$EMAIL"'"' "$payload" "account missing from the payload"
assert_jq '.generatedAt | test("^[0-9]{4}-")' "$payload" "generatedAt is not a timestamp"

# Four live tasks: completed is filtered out of the dashboard.
assert_jq '.tickets | length == 4' "$payload" "expected the four live tasks"
assert_jq '[.tickets[].key] | index("105") == null' "$payload" "a Completed task was not filtered out"
assert_jq '.tickets[0].key == "101"' "$payload" "permalink id missing"
assert_jq '.tickets[0].summary == "Refresh card limit"' "$payload" "title missing"
assert_jq '.tickets[0].type == "Planned"' "$payload" "dates.type missing"
assert_jq '.tickets[0].status == "In Progress"' "$payload" "custom status name missing"
assert_jq '.tickets[0].statusCategory == "indeterminate"' "$payload" "started planned task is not in progress"
assert_jq '.tickets[0].spaceName == "Demo"' "$payload" "space name missing"
assert_jq '.tickets[0].projectName == "Website Redesign"' "$payload" "project folder name missing"
assert_jq '.tickets[0].projectKey == "IEAAAAFOLDERWEB"' "$payload" "project folder id missing"
assert_jq '.tickets[0].breadcrumb[0].title == "Demo"' "$payload" "breadcrumb space missing"
assert_jq '.tickets[0].url == "https://'"$HOST"'/open.htm?id=101"' "$payload" "permalink is wrong"
assert_jq '.tickets[0].brief == "Raise the card limit before Friday."' "$payload" "brief description missing"

# Review is a custom status name; the category comes from started + Active.
assert_jq '[.tickets[] | select(.key == "102")][0].status == "Review"' "$payload" "Review name lost"
assert_jq '[.tickets[] | select(.key == "102")][0].statusCategory == "indeterminate"' "$payload" "overdue planned task is not in progress"

# Backlog and Deferred stay in the to-do category.
assert_jq '[.tickets[] | select(.key == "103")][0].statusCategory == "new"' "$payload" "backlog is not to-do"
assert_jq '[.tickets[] | select(.key == "104")][0].statusCategory == "new"' "$payload" "deferred is not to-do"

assert_jq '.projects | length == 2' "$payload" "spaces missing"
assert_jq '.projects[0].key == "IEAAAADEMO000001"' "$payload" "space key missing"
assert_jq '.projects[0].name == "Demo"' "$payload" "space name missing from the space list"
assert_jq '.weekState == "off"' "$payload" "week should be off unless asked for"

urls=$(cat "$STUB_DIR/urls")
assert_contains "$urls" "responsibles=[\"$USER_ID\"]" "the request does not filter on the current user"
assert_contains "$urls" 'status=["Active","Deferred"]' "the request does not exclude completed work"
assert_not_contains "$urls" "$TOKEN" "the token leaked into a request url"

assert_contains "$(cat "$STUB_DIR/creds")" "$TOKEN" "the token never reached curl through --config"
assert_not_contains "$(cat "$STUB_DIR/calls")" "$TOKEN" "the token leaked into a command line"
assert_not_contains "$(cat "$STUB_DIR/calls")" "secret-tool search" "the helper called secret-tool search"

# ---- Space narrowing

reset_state
store_credential
payload=$(run_helper --spaces IEAAAADEMO000001) || fail "helper failed with --spaces"
assert_contains "$(cat "$STUB_DIR/urls")" "/spaces/IEAAAADEMO000001/tasks" "space-scoped tasks were not requested"
assert_contains "$(cat "$STUB_DIR/urls")" "descendants=true" "space search did not include descendants"

reset_state
store_credential
payload=$(run_helper --spaces 'IEAAAADEMO000001) ; rm -rf /') || fail "helper failed on a hostile space list"
assert_not_contains "$(cat "$STUB_DIR/urls")" "rm -rf" "a hostile space id reached the URL"
assert_jq '.state == "ok"' "$payload" "a hostile space list broke the dashboard"

# ---- Week

reset_state
store_credential
payload=$(run_helper --week) || fail "helper failed with --week"
assert_jq '.weekState == "ok"' "$payload" "weekState is not ok"
assert_jq '.week.name == "This week"' "$payload" "week name missing"
assert_jq '.week.startDate | startswith("2026-08-10")' "$payload" "week did not start on Monday"
assert_jq '.week.endDate | startswith("2026-08-17")' "$payload" "week did not end next Monday"
assert_jq '.week.total >= 1' "$payload" "week has no tasks"
assert_jq '[.week.statuses[].name] | index("Completed") != null' "$payload" "completed week status missing"
assert_contains "$(cat "$STUB_DIR/urls")" "completedDate=" "completed-this-week was not requested"

# ---- Search

reset_state
store_credential
payload=$(run_helper --search supplier) || fail "helper failed on a title search"
assert_jq '.mode == "search"' "$payload" "mode is not search"
assert_jq '.tickets | length == 1' "$payload" "title search returned the wrong count"
assert_jq '.tickets[0].key == "102"' "$payload" "title search missed the supplier task"
assert_contains "$(cat "$STUB_DIR/urls")" "title=supplier" "title was not sent"

reset_state
store_credential
payload=$(run_helper --search 109) || fail "helper failed on a permalink search"
assert_jq '.tickets[0].key == "109"' "$payload" "permalink search missed the converted id"
assert_contains "$(cat "$STUB_DIR/urls")" "/ids" "permalink search did not convert the id"
assert_contains "$(cat "$STUB_DIR/urls")" "/tasks/IEAAAAAOKQAAAAA9" "converted id was not fetched"

reset_state
store_credential
payload=$(run_helper --task IEAAAAAOKQAAAAA9) || fail "helper failed on --task"
assert_jq '.mode == "preview"' "$payload" "mode is not preview"
assert_jq '.tickets[0].key == "109"' "$payload" "preview missed the task"
assert_jq '.tickets[0].description | test("Check line 4")' "$payload" "preview is missing the description"
assert_jq '.tickets[0].spaceName == "Demo"' "$payload" "preview space name missing"
assert_jq '.tickets[0].comments | length == 2' "$payload" "preview comments missing"
assert_jq '.tickets[0].attachments[0].name == "invoice.pdf"' "$payload" "preview attachments missing"
assert_contains "$(cat "$STUB_DIR/urls")" "/tasks/IEAAAAAOKQAAAAA9" "preview did not fetch the task"

reset_state
store_credential
payload=$(run_helper --search "") || fail "helper failed on a blank search"
assert_jq '.tickets | length == 0' "$payload" "a blank search is not empty"
assert_not_contains "$(cat "$STUB_DIR/urls")" "/tasks" "a blank search still called Wrike"

# ---- Failure states still exit zero

reset_state
payload=$(run_helper) || fail "unconfigured helper exited non zero"
assert_jq '.state == "unconfigured"' "$payload" "missing credential is not unconfigured"

reset_state
store_credential
payload=$(KEYRING_STUB_BROKEN=1 run_helper) || fail "locked keyring helper exited non zero"
assert_jq '.state == "keyring-unavailable"' "$payload" "a locked keyring is not keyring-unavailable"

reset_state
store_credential
payload=$(CURL_STUB_CODE=401 run_helper) || fail "401 helper exited non zero"
assert_jq '.state == "unauthorized"' "$payload" "401 is not unauthorized"

reset_state
store_credential
payload=$(CURL_STUB_FAIL=1 run_helper) || fail "network helper exited non zero"
assert_jq '.state == "network-error"' "$payload" "a transport failure is not network-error"

if ((failures > 0)); then
  echo "$failures test(s) failed" >&2
  exit 1
fi
echo "helper-test: all checks passed"
