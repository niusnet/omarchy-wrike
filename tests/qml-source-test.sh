#!/usr/bin/env bash
# Source-level checks on the QML.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

failures=0

fail() {
  echo "FAIL: $*" >&2
  failures=$((failures + 1))
}

has() {
  local file="$1" pattern="$2" label="$3"
  grep -qE "$pattern" "$ROOT/$file" || fail "$label"
}

hasnt() {
  local file="$1" pattern="$2" label="$3"
  grep -qE "$pattern" "$ROOT/$file" && fail "$label" || true
}

if command -v qmllint >/dev/null 2>&1; then
  for file in "$ROOT"/*.qml; do
    output=$(qmllint "$file" 2>&1 || true)
    if [[ -n $output ]]; then
      fail "$(basename "$file"): $output"
    fi
  done
fi

for property in loading state message site account fetchedAt tickets projects \
  searchResults searchQuery answeredQuery week weekState followedSpaces \
  weekBarChoice doneStatuses waitingCount assignedCount hasData \
  connecting authMessage previewTicket previewLoading; do
  has "Service.qml" "property.* $property\b" "Service.qml no longer exposes $property"
done

for method in refresh search clearSearch connectAccount disconnectAccount preview postComment logTime; do
  has "Service.qml" "function $method\(" "Service.qml no longer has $method()"
done

has "Service.qml" "Qt\.resolvedUrl" "Service.qml does not resolve the helper relatively"
hasnt "Service.qml" "/home/|/usr/local/" "Service.qml contains an absolute path"

has "Service.qml" "intSetting\(\"refreshIntervalSec\", 900, 60, 3600\)" \
  "the refresh interval is no longer clamped"

for state in unconfigured keyring-unavailable unauthorized forbidden network-error searching; do
  has "StateNotice.qml" "\"$state\"" "StateNotice.qml does not handle the $state state"
done

has "StateNotice.qml" "omarchy-wrike-auth" "StateNotice.qml never names the setup command"

for key in '"r"' '"y"' '"/"' '","' '"o"' ; do
  has "Panel.qml" "key === $key" "Panel.qml no longer handles $key"
done
has "Panel.qml" "onMoveRequested" "Panel.qml no longer moves the cursor"
has "Panel.qml" "onActivateRequested" "Panel.qml no longer opens the highlighted row"
has "Panel.qml" "onCloseRequested" "Panel.qml no longer closes on escape"
has "WrikeSearchField.qml" "Keys\.onUpPressed" "the search field swallows the up arrow again"
has "WrikeSearchField.qml" "Keys\.onDownPressed" "the search field swallows the down arrow again"

hasnt "Panel.qml" "elide: Text\.ElideRight" \
  "Panel.qml is drawing text rows again instead of delegating to TaskRow"

lines=$(wc -l <"$ROOT/Panel.qml")
if ((lines > 450)); then
  fail "Panel.qml is $lines lines, over the 450 line limit"
fi

if ((failures > 0)); then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "qml-source-test: all checks passed"
