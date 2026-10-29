#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
source_file=home/run_onchange_configure-windows-terminal.ps1.tmpl
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Exercise the JSON patch and jq filter used by the deployment script.
awk '/^[[:space:]]*\$patch = @\047/{p=1; next} p && /^\047@/{exit} p' "$source_file" > "$tmp/patch.json"
jq -e '
  [.keybindings[] | select(.keys == "ctrl+c" or .keys == "ctrl+v")]
    | length == 2 and all(.id == "unbound")
' "$tmp/patch.json" >/dev/null
jq -e '
  any(.keybindings[]; .keys == "ctrl+shift+c" and .id == "Terminal.CopyToClipboard") and
  any(.keybindings[]; .keys == "ctrl+shift+v" and .id == "Terminal.PasteFromClipboard")
' "$tmp/patch.json" >/dev/null
echo 'PASS: clipboard bindings'

# Capture the actual jq expression, including a multiline expression.
sed -n "/\$merged = .*jq -s '/,/^    if (\$LASTEXITCODE/p" "$source_file" |
  sed '1s/.*jq -s '\''//; $d; s/'\''$//' > "$tmp/merge.jq"
merge() { jq -s -f "$tmp/merge.jq" "$1" "$tmp/patch.json"; }
cat > "$tmp/existing.json" <<'EOF'
{"keybindings":[{"keys":"alt+f8","id":"User.local"}],
 "actions":[{"id":"User.local","command":{"action":"sendInput","input":"test"}}],
 "profiles":{"list":[{"name":"Local","commandline":"pwsh"}]},"theme":"dark"}
EOF
merge "$tmp/existing.json" > "$tmp/merged.json"
jq -e '
 any(.keybindings[]; .keys == "alt+f8" and .id == "User.local") and
 any(.actions[]; .id == "User.local" and .command.input == "test") and
 .profiles.list == [{"name":"Local","commandline":"pwsh"}] and .theme == "dark"
' "$tmp/merged.json" >/dev/null
echo 'PASS: unrelated settings preserved'

cat > "$tmp/conflicts.json" <<'EOF'
{"keybindings":[{"keys":["CTRL+V","alt+f9"],"id":"User.shared"},
 {"keys":"shift+ctrl+c","id":"User.old"},{"keys":"ctrl+v","id":"User.duplicate"}],
 "actions":[{"keys":["ctrl+c","alt+f10"],"command":"copy"},
 {"keys":"ctrl+v","command":"paste","id":"User.legacy"},
 {"id":"User.splitPane.auto.duplicate","command":"splitPane","keys":["ctrl+v","alt+f8"]},
 {"id":"User.named","name":"Keep me","command":"paste"}]}
EOF
merge "$tmp/conflicts.json" > "$tmp/conflicts-merged.json"
jq -e --argjson managed "$(jq '.keybindings | length' "$tmp/patch.json")" '
 .keybindings | length == ($managed + 1) and
 any(.[]; .keys == ["alt+f9"] and .id == "User.shared") and
 ([.[] | select(.keys == "ctrl+v")] | length == 1)
' "$tmp/conflicts-merged.json" >/dev/null
jq -e '
 any(.actions[]; .keys == ["alt+f10"] and .command == "copy") and
 any(.actions[]; .id == "User.legacy" and (has("keys") | not)) and
 any(.actions[]; .id == "User.splitPane.auto.duplicate" and .keys == ["alt+f8"] and .command.splitMode == "duplicate") and
 any(.actions[]; .id == "User.named" and .name == "Keep me")
' "$tmp/conflicts-merged.json" >/dev/null
echo 'PASS: conflicting chords removed, legacy actions retained'
merge "$tmp/conflicts-merged.json" > "$tmp/twice.json"
cmp "$tmp/conflicts-merged.json" "$tmp/twice.json"
echo 'PASS: repeated application is idempotent'
