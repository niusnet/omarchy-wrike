#!/usr/bin/env bash
# Tests for omarchy-wrike-auth.
#
# Every external command the script touches is stubbed inside a sandbox that
# takes over PATH, so no real network call is made and no real keyring entry is
# written. The stubs record every argument vector they are invoked with, which
# is what lets the last test assert the property that matters most: the API
# token never reaches a command line, where any local process could read it out
# of ps.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/omarchy-wrike-auth"

TOKEN="TESTTOKENvalue1234567890"
EMAIL="probe@example.com"
HOST="www.wrike.com"
EU_HOST="app-eu.wrike.com"

failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
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
mkdir -p "$STUB_DIR" "$sandbox/bin"

for tool in bash cat rm mktemp jq; do
  path=$(command -v "$tool" 2>/dev/null) && ln -sf "$path" "$sandbox/bin/$(basename "$tool")"
done

cat >"$sandbox/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >>"$STUB_DIR/calls"
config=""
output=""
url=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[i]}" in
  --config) config="${args[i + 1]}" ;;
  --output) output="${args[i + 1]}" ;;
  --url) url="${args[i + 1]}" ;;
  esac
done
if [[ -n $config && -r $config ]]; then
  cat "$config" >>"$STUB_DIR/creds"
fi

if [[ ${CURL_STUB_FAIL:-0} == 1 ]]; then
  echo "curl: (6) Could not resolve host" >&2
  exit 6
fi
if [[ -n $output ]]; then
  if [[ -n ${CURL_STUB_BODY:-} ]]; then
    printf '%s' "$CURL_STUB_BODY" >"$output"
  else
    cat >"$output" <<'BODY'
{"kind":"contacts","data":[{"id":"KUAAAAAA","firstName":"Test","lastName":"User","primaryEmail":"probe@example.com"}]}
BODY
  fi
fi
if [[ $url == *app-eu.wrike.com* ]]; then
  printf '%s' "${CURL_STUB_CODE_EU:-${CURL_STUB_CODE:-200}}"
elif [[ $url == *app-us2.wrike.com* ]]; then
  printf '%s' "${CURL_STUB_CODE_US2:-${CURL_STUB_CODE:-200}}"
else
  printf '%s' "${CURL_STUB_CODE_WWW:-${CURL_STUB_CODE:-200}}"
fi
STUB

cat >"$sandbox/bin/secret-tool" <<'STUB'
#!/usr/bin/env bash
printf 'secret-tool %s\n' "$*" >>"$STUB_DIR/calls"
action="${1:-}"
shift || true
case "$action" in
store)
  cat >"$STUB_DIR/vault"
  label=""
  attrs=()
  while (($# > 0)); do
    case "$1" in
    --label=*)
      label="${1#--label=}"
      shift
      ;;
    --label)
      label="$2"
      shift 2
      ;;
    *)
      attrs+=("$1" "$2")
      shift 2
      ;;
    esac
  done
  {
    printf 'label = %s\n' "$label"
    for ((i = 0; i < ${#attrs[@]}; i += 2)); do
      printf 'attribute.%s = %s\n' "${attrs[i]}" "${attrs[i + 1]}"
    done
  } >"$STUB_DIR/vault-attrs"
  ;;
lookup)
  [[ -s $STUB_DIR/vault ]] || exit 1
  cat "$STUB_DIR/vault"
  ;;
search)
  [[ -s $STUB_DIR/vault ]] || exit 1
  printf '[/org/freedesktop/secrets/collection/login/1]\n'
  printf 'secret = %s\n' "$(cat "$STUB_DIR/vault")"
  cat "$STUB_DIR/vault-attrs" >&2
  ;;
clear)
  rm -f "$STUB_DIR/vault" "$STUB_DIR/vault-attrs"
  ;;
*)
  exit 2
  ;;
esac
STUB

chmod +x "$sandbox/bin/curl" "$sandbox/bin/secret-tool"

reset_state() {
  rm -f "$STUB_DIR/calls" "$STUB_DIR/creds" "$STUB_DIR/vault" "$STUB_DIR/vault-attrs"
  : >"$STUB_DIR/calls"
  : >"$STUB_DIR/creds"
}

run_setup() {
  printf '%s\n%s\n' "$1" "$2" | PATH="$sandbox/bin" "$SCRIPT" 2>&1
}

run_flag() {
  PATH="$sandbox/bin" "$SCRIPT" "$@" 2>&1
}

run_connect() {
  printf '%s\n' "$1" | PATH="$sandbox/bin" "$SCRIPT" --connect 2>&1
}

bash -n "$SCRIPT" || fail "script does not parse"
PATH="$sandbox/bin" "$SCRIPT" --help >/dev/null || fail "--help failed"

reset_state
output=$(run_setup "$HOST" "$TOKEN") || fail "setup failed on a valid token: $output"

stored=$(cat "$STUB_DIR/vault")
jq -e . >/dev/null 2>&1 <<<"$stored" || fail "the stored credential is not valid JSON"
[[ $(jq -r .token <<<"$stored") == "$TOKEN" ]] || fail "the stored token is wrong"
[[ $(jq -r .host <<<"$stored") == "$HOST" ]] || fail "the stored host is wrong"
[[ $(jq -r .account <<<"$stored") == "$EMAIL" ]] || fail "the stored account is wrong"
[[ $(jq -r .userId <<<"$stored") == "KUAAAAAA" ]] || fail "the stored user id is wrong"
[[ $(jq -r .base <<<"$stored") == "https://$HOST/api/v4" ]] || fail "the stored base is wrong"

assert_contains "$(cat "$STUB_DIR/vault-attrs")" "attribute.service = omarchy-wrike" "service attribute missing"
assert_contains "$(cat "$STUB_DIR/calls")" "https://$HOST/api/v4/contacts?me=true" "validation did not hit /contacts?me=true"
assert_not_contains "$(cat "$STUB_DIR/calls")" "secret-tool search" "the script called secret-tool search"
assert_contains "$(cat "$STUB_DIR/creds")" "$TOKEN" "the token never reached curl through --config"
assert_not_contains "$(cat "$STUB_DIR/calls")" "$TOKEN" "the token leaked into a command line"

reset_state
output=$(run_setup "https://$HOST/" "$TOKEN") || fail "setup failed on a URL-shaped host: $output"
[[ $(jq -r .host <"$STUB_DIR/vault") == "$HOST" ]] || fail "host was not normalised"
assert_not_contains "$(cat "$STUB_DIR/calls")" "https://https://" "a URL-shaped answer produced a doubled scheme"

reset_state
output=$(run_setup "eu" "$TOKEN") || fail "setup failed on a short eu host: $output"
[[ $(jq -r .host <"$STUB_DIR/vault") == "$EU_HOST" ]] || fail "eu was not normalised to app-eu.wrike.com"
assert_contains "$(cat "$STUB_DIR/calls")" "https://$EU_HOST/api/v4/contacts?me=true" "the eu host was not tried first"

reset_state
output=$(run_setup "" "$TOKEN") || fail "setup failed on a blank host: $output"
[[ $(jq -r .host <"$STUB_DIR/vault") == "$HOST" ]] || fail "a blank host did not default to www.wrike.com"

# The token must never leave this machine toward a host that is not a known
# Wrike datacenter. A look-alike or pasted attacker URL is rejected before curl.
reset_state
if run_setup "evil.example.com" "$TOKEN" >/dev/null 2>&1; then
  fail "setup accepted an unknown host"
fi
[[ ! -s "$STUB_DIR/vault" ]] || fail "an unknown host stored a credential"
assert_not_contains "$(cat "$STUB_DIR/calls")" "evil.example.com" "the token was sent to an unknown host"
assert_not_contains "$(cat "$STUB_DIR/creds")" "$TOKEN" "the token reached curl before the host was confirmed"

reset_state
if run_setup "www.wrike.com.evil.example.com" "$TOKEN" >/dev/null 2>&1; then
  fail "setup accepted a look-alike host"
fi
assert_not_contains "$(cat "$STUB_DIR/calls")" "evil.example.com" "a look-alike host was contacted"

reset_state
if run_connect "$(jq -nc --arg host "https://evil.example.com/steal" --arg token "$TOKEN" '{host: $host, token: $token}')" >/dev/null 2>&1; then
  fail "--connect accepted an unknown host"
fi
[[ ! -s "$STUB_DIR/vault" ]] || fail "--connect stored a credential for an unknown host"
assert_not_contains "$(cat "$STUB_DIR/calls")" "evil.example.com" "--connect sent the token to an unknown host"
assert_not_contains "$(cat "$STUB_DIR/creds")" "$TOKEN" "--connect reached curl before the host was confirmed"

# A token that only the EU datacenter accepts should fall through and store
# that host, because people often do not know which DC they are on.
reset_state
output=$(CURL_STUB_CODE_WWW=404 CURL_STUB_CODE_US2=404 CURL_STUB_CODE_EU=200 \
  run_setup "$HOST" "$TOKEN") || fail "setup failed when only EU accepted the token: $output"
[[ $(jq -r .host <"$STUB_DIR/vault") == "$EU_HOST" ]] || fail "did not fall through to the EU host"

reset_state
if CURL_STUB_CODE=401 run_setup "$HOST" "$TOKEN" >/dev/null 2>&1; then
  fail "setup succeeded despite a 401"
fi
[[ ! -s "$STUB_DIR/vault" ]] || fail "a rejected token was stored anyway"

reset_state
if CURL_STUB_FAIL=1 run_setup "$HOST" "$TOKEN" >/dev/null 2>&1; then
  fail "setup succeeded despite a transport failure"
fi
[[ ! -s "$STUB_DIR/vault" ]] || fail "a token was stored despite a transport failure"

reset_state
output=$(run_setup "$HOST" "" 2>&1 || true)
assert_contains "$output" "cancelled" "an empty token is not described as cancelled"
[[ ! -s "$STUB_DIR/vault" ]] || fail "an empty token was stored anyway"

has() {
  local pattern="$1" label="$2"
  grep -qE "$pattern" "$SCRIPT" || fail "$label"
}

has 'trap cancelled INT' "Ctrl+C is not trapped as cancel"
has 'stty echo' "the script never restores terminal echo"

reset_state
if run_flag --status >/dev/null 2>&1; then
  fail "--status succeeded with no credential stored"
fi
output=$(run_flag --status 2>&1 || true)
assert_contains "$output" "omarchy-wrike-auth" "--status does not point at the setup command"

reset_state
run_setup "$HOST" "$TOKEN" >/dev/null || fail "setup failed before the status check"
output=$(run_flag --status) || fail "--status failed with a credential stored"
assert_contains "$output" "$HOST" "--status does not show the host"
assert_contains "$output" "$EMAIL" "--status does not show the account"
assert_not_contains "$output" "$TOKEN" "--status printed the token"
assert_not_contains "$output" "secret =" "--status echoed raw secret-tool output"

reset_state
output=$(run_connect "$(jq -nc --arg host "$HOST" --arg token "$TOKEN" '{host: $host, token: $token}')") ||
  fail "--connect failed on a valid payload: $output"
[[ $(jq -r .token <"$STUB_DIR/vault") == "$TOKEN" ]] || fail "--connect did not store the token"
assert_not_contains "$(cat "$STUB_DIR/calls")" "$TOKEN" "--connect leaked the token into a command line"
assert_contains "$(cat "$STUB_DIR/creds")" "$TOKEN" "--connect never reached curl through --config"

reset_state
if run_connect "" >/dev/null 2>&1; then
  fail "--connect succeeded with empty stdin"
fi
[[ ! -s "$STUB_DIR/vault" ]] || fail "empty --connect stored a credential"

run_flag --clear >/dev/null || fail "--clear failed"
[[ ! -s "$STUB_DIR/vault" ]] || fail "--clear left the secret behind"
assert_contains "$(cat "$STUB_DIR/calls")" "secret-tool clear service omarchy-wrike" "--clear did not call secret-tool clear"

if ((failures > 0)); then
  echo "$failures test(s) failed" >&2
  exit 1
fi
echo "auth-test: all checks passed"
