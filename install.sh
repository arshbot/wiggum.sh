#!/bin/bash
# curl -fsSL wiggum.sh | bash
set -euo pipefail

VERSION="1.0.0"
PLUGIN="ralph-wiggum"
CLAUDE_DIR="${HOME}/.claude"
DEST="${CLAUDE_DIR}/plugins/cache/claude-code-plugins/${PLUGIN}/${VERSION}"
MANIFEST="${CLAUDE_DIR}/plugins/installed_plugins.json"
RAW="https://raw.githubusercontent.com/arshbot/wiggum.sh/main/plugin"

info()  { printf "  \033[1m%s\033[0m\n" "$*"; }
ok()    { printf "  \033[32m✓\033[0m %s\n" "$*"; }
err()   { printf "  \033[31m✗\033[0m %s\n" "$*" >&2; exit 1; }

info "wiggum v${VERSION}"
echo ""

# Preflight
[[ -d "$CLAUDE_DIR" ]] || err "~/.claude not found — install Claude Code first"
command -v curl >/dev/null || err "curl is required"

# Download plugin
rm -rf "$DEST"
mkdir -p "$DEST"/{.claude-plugin,commands,hooks,scripts}

FILES=(
  .claude-plugin/plugin.json
  commands/help.md
  commands/ralph-loop.md
  commands/cancel-ralph.md
  hooks/hooks.json
  hooks/stop-hook.sh
  scripts/setup-ralph-loop.sh
)

for f in "${FILES[@]}"; do
  curl -fsSL "${RAW}/${f}" -o "${DEST}/${f}" || err "Failed to download ${f}"
done

chmod +x "${DEST}/hooks/stop-hook.sh" "${DEST}/scripts/setup-ralph-loop.sh"
ok "Downloaded plugin"

# Register in manifest
mkdir -p "$(dirname "$MANIFEST")"

ENTRY="{\"version\":\"${VERSION}\",\"installPath\":\"${DEST}\",\"scope\":\"user\",\"installedAt\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"

if [[ -f "$MANIFEST" ]]; then
  # Merge into existing manifest — try node, python3, then jq
  UPDATED=false
  for cmd in \
    "node -e \"const fs=require('fs'),f='${MANIFEST}',p=JSON.parse(fs.readFileSync(f,'utf8'));p['${PLUGIN}']=${ENTRY};fs.writeFileSync(f,JSON.stringify(p,null,2))\"" \
    "python3 -c \"import json;f='${MANIFEST}';p=json.load(open(f));p['${PLUGIN}']=${ENTRY};json.dump(p,open(f,'w'),indent=2)\"" \
    "jq --argjson e '${ENTRY}' '.[\"${PLUGIN}\"]=\$e' '${MANIFEST}' > '${MANIFEST}.tmp' && mv '${MANIFEST}.tmp' '${MANIFEST}'"
  do
    if eval "$cmd" 2>/dev/null; then UPDATED=true; break; fi
  done
  $UPDATED || err "Could not update ${MANIFEST} — need node, python3, or jq"
else
  # Create fresh
  printf '{\n  "%s": %s\n}\n' "$PLUGIN" "$ENTRY" > "$MANIFEST"
fi

ok "Registered plugin"

echo ""
info "Done — restart Claude Code to activate"
echo ""
echo "  Commands:"
echo "    /ralph-loop <prompt>  [--prompt-file FILE] [--max-iterations N]"
echo "    /cancel-ralph"
echo ""
