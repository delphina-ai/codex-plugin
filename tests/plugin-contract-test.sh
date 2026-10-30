#!/usr/bin/env bash
# Structural checks on the plugin itself.
#
# CI installs the plugin into a throwaway Codex home, which covers manifest
# shape. What that cannot see is whether the pieces still refer to each other
# correctly: a skill that names a script which was renamed, a skill that
# documents a flag the script stopped accepting, a script that lost its
# executable bit. Each of those fails at run time, on a customer's machine, in
# the middle of a task.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$here/.."

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

# --- the manifests agree with each other and with the tree ------------------
echo "manifests agree and point at files that exist"
# Codex reads two manifests: the marketplace that lists the plugin and the
# plugin's own. A rename in one leaves `codex plugin add delphina@delphina`
# failing at install time, which is the first thing a new user runs.
while IFS='=' read -r label result; do
  [[ -z "$label" ]] && continue
  check "$label" "yes" "$result"
done <<<"$(
  python3 - "$root" <<'PY'
import json, os, sys

root = sys.argv[1]
with open(os.path.join(root, ".codex-plugin/plugin.json")) as fh:
    plugin = json.load(fh)
with open(os.path.join(root, ".agents/plugins/marketplace.json")) as fh:
    market = json.load(fh)

entries = [p for p in market.get("plugins", []) if p.get("name") == plugin["name"]]
yes = lambda ok: "yes" if ok else "no"
print(f"marketplace lists the plugin by its manifest name={yes(len(entries) == 1)}")
source = entries[0].get("source", {}) if entries else {}
print(f"marketplace entry is the repository root={yes(source.get('path') == './')}")
for field in ("skills", "mcpServers"):
    path = plugin.get(field, "")
    print(f"plugin.json {field} path exists={yes(bool(path) and os.path.exists(os.path.join(root, path)))}")
PY
)"

# --- the MCP URL is literal -------------------------------------------------
echo "the MCP server URL needs no expansion"
# Claude Code expands ${VAR:-default} in .mcp.json; nothing says Codex does, and
# `codex mcp list` shows such a value verbatim. A literal URL removes the
# question. Developers override it with `-c mcp_servers.delphina.url=...`.
check "delphina points at production" "https://app.delphina.ai/api/mcp" \
  "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["mcpServers"]["delphina"]["url"])' "$root/.mcp.json")"

# --- every script is executable --------------------------------------------
echo "all shipped scripts are executable"
for f in "$root"/scripts/*.sh; do
  rel="scripts/$(basename "$f")"
  check "$rel is executable" "yes" "$([[ -x "$f" ]] && echo yes || echo no)"
done

# --- skills invoke flags their scripts accept ------------------------------
echo "skills and scripts agree on their interface"
# The sync-knowledge skill tells the model how to call apply-snapshot.sh. A
# rename on either side leaves the other wrong, and the failure surfaces as the
# model running a command that errors mid-task. This has happened once already,
# when --sha became --snapshot.
documented="$(grep -o '\-\-[a-z][a-z-]*' "$root/skills/sync-knowledge/SKILL.md" | sort -u)"
accepted="$(grep -o '^\s*--[a-z][a-z-]*)' "$root/scripts/apply-snapshot.sh" | tr -d ' )' | sort -u)"

while read -r flag; do
  [[ -z "$flag" ]] && continue
  check "apply-snapshot.sh accepts $flag as the skill documents" "yes" \
    "$(grep -qx -- "$flag" <<<"$accepted" && echo yes || echo no)"
done <<<"$documented"

# --- skills reach scripts by path, not by environment variable -----------
echo "skills refer to scripts by a path that resolves"
# Claude Code substitutes ${CLAUDE_PLUGIN_ROOT} in skill text. Codex sets
# PLUGIN_ROOT for hooks only, so a skill that names a script through either
# variable hands the model a command that cannot run. Skills name scripts
# relative to their own SKILL.md, and Codex tells the model where that file is.
for skill in "$root"/skills/*/SKILL.md; do
  rel="${skill#"$root"/}"
  check "$rel names no script through an environment variable" "0" \
    "$(grep -cE '\$\{?(CLAUDE_)?PLUGIN_ROOT' "$skill" || true)"
  while read -r ref; do
    [[ -z "$ref" ]] && continue
    check "$rel: $ref resolves" "yes" \
      "$([[ -x "$(dirname "$skill")/$ref" ]] && echo yes || echo no)"
  done <<<"$(grep -oE '\.\./\.\./scripts/[A-Za-z0-9_.-]+' "$skill" | sort -u)"
done

# --- skill names match their directories -----------------------------------
echo "skill names match their directories"
# Codex lists a skill under its frontmatter name, namespaced by the plugin
# (delphina:sync-knowledge). Skills refer to each other by that name, so a
# directory rename that leaves the name behind breaks the reference silently.
for skill in "$root"/skills/*/SKILL.md; do
  dir="$(basename "$(dirname "$skill")")"
  check "skills/$dir is named $dir" "$dir" \
    "$(sed -n 's/^name: *//p' "$skill" | head -1)"
done

echo
if [[ "$failures" -gt 0 ]]; then
  echo "$failures check(s) failed" >&2
  exit 1
fi
echo "all checks passed"
