#!/bin/sh
# bw-get.test.sh — black-box tests for home/dot_local/bin/executable_bw-get.
#
# `curl` is a stub that answers from a fixture, so no Bitwarden and no network
# are needed. PATH holds only the stub dir and /usr/bin:/bin, so bw-get picks
# `curl`, not a real `curl.exe` on a WSL /mnt/c PATH.

repo=$(cd "$(dirname "$0")/.." && pwd -P)
t=$(mktemp -d) || exit 1
trap 'rm -rf "$t"' EXIT
failures=0
command -v jq >/dev/null || { echo "FATAL: jq is required (bw-get parses bw serve JSON with it)"; exit 1; }

mkdir -p "$t/.local/bin" "$t/stub"
cp "$repo/home/dot_local/bin/executable_bw-get" "$t/.local/bin/bw-get"

cat > "$t/items.json" <<'EOF'
{"success":true,"data":{"object":"list","data":[
 {"id":"id-corp","name":"corp","login":{"username":"ad-user","password":"ad-secret","totp":"otpauth://x"}},
 {"id":"id-gl","name":"gitlab/corp-token","login":{"password":"glpat-vault","totp":null}},
 {"id":"id-gl2","name":"gitlab/corp-token-old","login":{"password":"wrong","totp":null}}]}}
EOF

# STUB_MODE: ok | locked | down. STUB_LASTSYNC: ISO time in the status reply.
cat > "$t/stub/curl" <<'EOF'
#!/bin/sh
in=$(cat)
[ -n "$in" ] && echo "$in" >> "$HOME/stdin.log"
[ "$STUB_MODE" = down ] && exit 7
for a; do url=$a; done
case $url in
  */status)
    st=unlocked; [ "$STUB_MODE" = locked ] && st=locked
    printf '{"success":true,"data":{"object":"template","template":{"status":"%s","lastSync":"%s"}}}\n' "$st" "$STUB_LASTSYNC" ;;
  */sync) echo "$*" >> "$HOME/sync-args.log"; echo sync >> "$HOME/sync.log"; echo '{"success":true}' ;;
  */list/object/items*) cat "$HOME/items.json" ;;
  */object/totp/id-corp) echo '{"success":true,"data":{"object":"string","data":"123456"}}' ;;
  *) echo '{"success":false}' ;;
esac
EOF
chmod +x "$t/stub/"* "$t/.local/bin/bw-get"

fresh=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
stale=2020-01-01T00:00:00.000Z

run() {  # $1 mode, $2 lastSync, rest = command; stdin is a pipe with data
  mode=$1; last=$2; shift 2
  rm -f "$t/stdin.log" "$t/sync.log" "$t/sync-args.log"
  echo NOT-YOURS | env -i HOME="$t" PATH="$t/stub:/usr/bin:/bin" STUB_MODE="$mode" \
    STUB_LASTSYNC="$last" \
    "$@" 2>/dev/null
}

# $1 name, $2 expected rc, $3 expected stdout, $4 got rc, $5 got stdout
expect() {
  if [ "$4" != "$2" ] || [ "$5" != "$3" ]; then
    echo "FAIL: $1: rc=$4 out='$5', expected rc=$2 out='$3'"
    failures=$((failures + 1))
  fi
  if [ -s "$t/stdin.log" ]; then
    echo "FAIL: $1: curl received the caller's stdin"
    failures=$((failures + 1))
  fi
}

B="$t/.local/bin/bw-get"
out=$(run ok "$fresh" "$B" corp);                   expect "password"       0 ad-secret "$?" "$out"
out=$(run ok "$fresh" "$B" corp totp);              expect "totp"           0 123456    "$?" "$out"
out=$(run ok "$fresh" "$B" corp username);          expect "username"       0 ad-user   "$?" "$out"
out=$(run ok "$fresh" "$B" gitlab/corp-token username); expect "no username" 1 ''        "$?" "$out"
out=$(run ok "$fresh" "$B" gitlab/corp-token);      expect "exact name"     0 glpat-vault "$?" "$out"
out=$(run ok "$fresh" "$B" nope);                   expect "missing item"   1 ''        "$?" "$out"
out=$(run ok "$fresh" "$B" gitlab/corp-token totp); expect "missing field"  1 ''        "$?" "$out"
out=$(run locked "$fresh" "$B" corp);               expect "locked"         2 ''        "$?" "$out"
out=$(run down "$fresh" "$B" corp);                 expect "bw serve down"  2 ''        "$?" "$out"

run ok "$fresh" "$B" corp >/dev/null
[ -s "$t/sync.log" ] && { echo "FAIL: synced although lastSync is fresh"; failures=$((failures + 1)); }
run ok "$stale" "$B" corp >/dev/null
[ -s "$t/sync.log" ] || { echo "FAIL: did not sync although lastSync is stale"; failures=$((failures + 1)); }
# The sync leaves the machine (bw serve forwards it); a dropped packet must not hang the caller.
grep -qE -- '(^| )(-m|--max-time) [0-9]+' "$t/sync-args.log" 2>/dev/null \
  || { echo "FAIL: sync request has no time limit (-m)"; failures=$((failures + 1)); }

[ "$failures" -eq 0 ] && echo "ok: bw-get" || exit 1
