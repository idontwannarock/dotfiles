#!/bin/sh
# gpg-prompt-guard.test.sh — the headless `pass` callers must not start pinentry
# on a terminal that belongs to someone else.
#
# With a cold gpg cache, pinentry draws on the terminal that GPG_TTY names. An
# agent inherits GPG_TTY from the terminal that started it, so its `pass` call
# destroys that session. A retry loop makes it worse: each killed pinentry is
# replaced by the next call. On 2026-09-24 an agent's `glab` did this.
#
# The rule under test: a caller reads the vault only when its controlling
# terminal is GPG_TTY, or when gpg-cache-warm says the cache is warm.
#
# WHY THE PTY ROWS EXIST. The first fix used `[ -t 0 ]`. It passed every
# no-terminal case, but an agent that runs in a PTY also passes `[ -t 0 ]`, while
# its GPG_TTY names another terminal. Rows that only cover "no terminal" would
# have stayed green on that fix.
#
# `pass` and gpg-cache-warm are stubs. The stub pass records each call, so no
# real decrypt runs and no pinentry can appear.

repo=$(cd "$(dirname "$0")/.." && pwd -P)
t=$(mktemp -d) || exit 1
trap 'rm -rf "$t"' EXIT
failures=0

mkdir -p "$t/.local/bin" "$t/stub" "$t/.corp-ssh" "$t/.password-store"
sed -n '/^glab() {/,/^}/p' "$repo/home/.chezmoitemplates/shell-common/base" > "$t/glab.sh"
[ -s "$t/glab.sh" ] || { echo "FAIL: glab() not found in shell-common/base"; exit 1; }
cp "$repo/home/dot_local/bin/executable_corp-ssh-askpass" "$t/.local/bin/corp-ssh-askpass"
printf '#!/bin/sh\necho x >> "$HOME/pass.log"; echo secret\n' > "$t/stub/pass"
printf '#!/bin/sh\nexit 0\n' > "$t/stub/glab"
printf '#!/bin/sh\n[ "$WARM" = 1 ]\n' > "$t/.local/bin/gpg-cache-warm"
printf 'pass_path: corp\nhosts:\n  - host1\n' > "$t/.corp-ssh/hosts.yaml"
chmod +x "$t/stub/"* "$t/.local/bin/"*

# One subject script per caller. $1 = "own" sets GPG_TTY to our own terminal,
# as the shell rc does for a human; anything else keeps the inherited value.
cat > "$t/glab-subject.sh" <<'EOF'
[ "$1" = own ] && export GPG_TTY=$(tty)
. "$HOME/glab.sh"
glab api >/dev/null 2>&1
EOF
cat > "$t/askpass-subject.sh" <<'EOF'
[ "$1" = own ] && export GPG_TTY=$(tty)
"$HOME/.local/bin/corp-ssh-askpass" '(u@host1.corp) Password:' >/dev/null 2>&1
EOF

envs="HOME=$t PATH=$t/stub:/usr/bin:/bin GITLAB_HOST=x GITLAB_TOKEN=envtok GLAB_CONFIG_DIR=$t GPG_TTY=/dev/pts/999"

# $1 subject, $2 warm, $3 mode (noctty | pty | own), $4 expected pass calls
check() {
    rm -f "$t/pass.log"
    case $3 in
        noctty) setsid -w env -i $envs WARM="$2" bash "$t/$1-subject.sh" x </dev/null ;;
        pty)    script -qec "env -i $envs WARM=$2 bash $t/$1-subject.sh x" /dev/null >/dev/null ;;
        own)    script -qec "env -i $envs WARM=$2 bash $t/$1-subject.sh own" /dev/null >/dev/null ;;
    esac
    got=$(cat "$t/pass.log" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$got" != "$4" ]; then
        echo "FAIL: $1 warm=$2 $3: pass called $got time(s), expected $4"
        failures=$((failures + 1))
    fi
}

for subject in glab askpass; do
    check "$subject" 0 noctty 0   # agent Bash tool, cold: must not prompt
    check "$subject" 0 pty    0   # agent in a PTY, foreign GPG_TTY, cold: must not prompt
    check "$subject" 0 own    1   # human in own shell, cold: prompt is wanted
    check "$subject" 1 noctty 1   # warm: cache hit, no prompt possible
    check "$subject" 1 pty    1
    check "$subject" 1 own    1
done

# A retry loop must get a fast failure every time, never a pass call.
rm -f "$t/pass.log"
setsid -w env -i $envs WARM=0 bash -c "for i in 1 2 3 4 5 6 7 8 9 10; do bash $t/glab-subject.sh x; bash $t/askpass-subject.sh x; done" </dev/null
got=$(cat "$t/pass.log" 2>/dev/null | wc -l | tr -d ' ')
[ "$got" = 0 ] || { echo "FAIL: retry loop, cold: pass called $got time(s), expected 0"; failures=$((failures + 1)); }

# macOS has no gpg-cache-warm; the wrapper must still read the vault there.
rm "$t/.local/bin/gpg-cache-warm"
check glab 0 noctty 1

[ "$failures" -eq 0 ] && echo "ok: gpg-prompt-guard" || exit 1
