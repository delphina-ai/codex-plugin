#!/usr/bin/env bash
# Install the plugin from this checkout into a throwaway Codex home, and check
# what Codex actually loaded.
#
# Codex has no `plugin validate`. Installing is the closest thing: it parses
# both manifests, registers the MCP server, and lists the skills the model will
# see. A manifest Codex starts rejecting shows up here, not on a customer's
# machine at `codex plugin add`.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"

command -v codex >/dev/null 2>&1 || { echo "codex is required but not installed" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export CODEX_HOME="$work/codex-home"
mkdir -p "$CODEX_HOME" "$work/project"

failures=0
check() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  ok: $label"
  else
    echo "  FAIL: $label — expected [$expected], got [$actual]" >&2
    failures=$((failures + 1))
  fi
}

codex --version

echo "installs from the marketplace in this checkout"
codex plugin marketplace add "$root" >"$work/out" 2>&1; rc=$?
check "marketplace add succeeds" "0" "$rc"
codex plugin add delphina@delphina >"$work/out" 2>&1; rc=$?
check "plugin add succeeds" "0" "$rc"
[[ "$rc" == 0 ]] || cat "$work/out" >&2

version="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["version"])' "$root/.codex-plugin/plugin.json")"
check "caches the manifest's version" "yes" \
  "$([[ -d "$CODEX_HOME/plugins/cache/delphina/delphina/$version" ]] && echo yes || echo no)"

echo "registers the MCP server"
check "delphina is a streamable HTTP server at production" \
  "streamable_http https://app.delphina.ai/api/mcp" \
  "$(
    codex mcp list --json 2>/dev/null | python3 -c '
import json, sys
servers = {s["name"]: s for s in json.load(sys.stdin)}
t = servers.get("delphina", {}).get("transport", {})
print(t.get("type"), t.get("url"))
'
  )"

echo "shows the model every skill"
# prompt-input renders what a new session would send, without calling a model,
# so it needs no account.
(cd "$work/project" && codex debug prompt-input "hi" >"$work/prompt.json" 2>"$work/prompt.err"); rc=$?
check "prompt-input succeeds" "0" "$rc"
[[ "$rc" == 0 ]] || cat "$work/prompt.err" >&2
for skill in "$root"/skills/*/; do
  name="delphina:$(basename "$skill")"
  check "$name is listed" "yes" \
    "$(grep -qF -- "- $name:" "$work/prompt.json" && echo yes || echo no)"
done

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
