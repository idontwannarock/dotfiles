#!/bin/sh
# corp-ssh-askpass.test.sh — black-box tests for
# home/dot_local/bin/executable_corp-ssh-askpass (the Linux/WSL bash helper).
#
# The helper reads credentials from `bw serve` over HTTP. `curl` is a stub that
# answers from a fixture, so no Bitwarden and no network are needed. PATH holds
# only the stub dir and /usr/bin:/bin, so the helper picks `curl`, not a real
# `curl.exe` on a WSL /mnt/c PATH.
#
# WHY THE STDIN ROW EXISTS. Under ProxyJump the jump ssh runs with -W, so its
# stdin is the tunnel and the helper inherits it. WSL interop forwards stdin to
# curl.exe, which ate tunnel bytes and broke the inner connection with
# "Bad packet length". The stub records any stdin it receives.

repo=$(cd "$(dirname "$0")/.." && pwd -P)
t=$(mktemp -d) || exit 1
trap 'rm -rf "$t"' EXIT
failures=0
command -v jq >/dev/null || { echo "FATAL: jq is required (the helper parses bw serve JSON with it)"; exit 1; }

mkdir -p "$t/stub" "$t/.corp-ssh"
cp "$repo/home/dot_local/bin/executable_corp-ssh-askpass" "$t/askpass"
chmod +x "$t/askpass"
printf 'pass_path: corp\n\npassword_otp_hosts:\n  - corp-host.example.com\n  - db-host.example.com\n' \
  > "$t/.corp-ssh/hosts.yaml"

cat > "$t/items.json" <<'EOF'
{"success":true,"data":{"object":"list","data":[
 {"id":"id-corp","name":"corp","login":{"password":"ad-secret","totp":"otpauth://x"}},
 {"id":"id-db","name":"corp/hosts/db-host","login":{"password":"db-secret","totp":null}},
 {"id":"id-other","name":"corp/hosts/db-host-2","login":{"password":"wrong","totp":null}}]}}
EOF

# STUB_MODE: ok | locked | down
cat > "$t/stub/curl" <<'EOF'
#!/bin/sh
in=$(cat)
[ -n "$in" ] && echo "$in" >> "$HOME/stdin.log"
[ "$STUB_MODE" = down ] && exit 7
for a; do url=$a; done
case $url in
  */sync) echo "$*" >> "$HOME/sync-args.log"; echo '{"success":true}' ;;
  */list/object/items*)
    if [ "$STUB_MODE" = locked ]; then echo '{"success":false,"message":"Vault is locked."}'
    else cat "$HOME/items.json"; fi ;;
  */object/totp/id-corp) echo '{"success":true,"data":{"object":"string","data":"123456"}}' ;;
  *) echo '{"success":false}' ;;
esac
EOF
chmod +x "$t/stub/curl"

# $1 name, $2 mode, $3 prompt, $4 expected rc, $5 expected stdout
check() {
  rm -f "$t/stdin.log"
  out=$(echo TUNNEL-BYTES | setsid -w env -i HOME="$t" PATH="$t/stub:/usr/bin:/bin" \
        STUB_MODE="$2" "$t/askpass" "$3" 2>/dev/null)
  rc=$?
  if [ "$rc" != "$4" ] || [ "$out" != "$5" ]; then
    echo "FAIL: $1: rc=$rc out='$out', expected rc=$4 out='$5'"
    failures=$((failures + 1))
  fi
  if [ -s "$t/stdin.log" ]; then
    echo "FAIL: $1: curl received the helper's stdin"
    failures=$((failures + 1))
  fi
}

check "shared password"        ok     '(u@corp-host.example.com) Password:'          0 ad-secret
check "OTP before Password"    ok     '(u@corp-host.example.com) One-time Password:' 0 123456
check "per-host password"      ok     "root@db-host.example.com's password: "        0 db-secret
check "locked fails closed"    locked "root@db-host.example.com's password: "        1 ''
check "bw serve down"          down   '(u@corp-host.example.com) Password:'          1 ''
check "unknown host, no tty"   ok     '(u@elsewhere.example.com) Password:'          1 ''

# The sync is the one request that leaves the machine: bw serve forwards it to
# the Bitwarden server. A firewall that drops packets would hang ssh on it, so
# the call must carry a time limit.
rm -f "$t/sync-args.log"
echo | setsid -w env -i HOME="$t" PATH="$t/stub:/usr/bin:/bin" STUB_MODE=ok \
  "$t/askpass" '(u@corp-host.example.com) Password:' >/dev/null 2>&1
grep -qE -- '(^| )(-m|--max-time) [0-9]+' "$t/sync-args.log" 2>/dev/null \
  || { echo "FAIL: sync request has no time limit (-m)"; failures=$((failures + 1)); }

[ "$failures" -eq 0 ] && echo "ok: corp-ssh-askpass" || exit 1
