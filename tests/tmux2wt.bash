#!/usr/bin/env bash

set -euo pipefail

if (( $# != 3 )); then
    printf 'Usage: %s /path/to/tmux2wt /path/to/ewt /path/to/tmux2\n' "${0##*/}" >&2
    exit 2
fi

sandbox="$(mktemp -d "${TMPDIR:-/tmp}/tmux2wt-test.XXXXXX")"
trap 'rm -rf -- "$sandbox"' EXIT
sandbox="$(cd "$sandbox" && pwd -P)"
mkdir "$sandbox/bin"
for script in "$@"; do
    script="$(cd "$(dirname "$script")" && pwd -P)/$(basename "$script")"
    ln -s "$script" "$sandbox/bin/$(basename "$script")"
done
export PATH="$sandbox/bin:$PATH"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_TERMINAL_PROMPT=0
export TMUX_TEST_LOG="$sandbox/tmux.log" TMUX_TEST_CWD="$sandbox/tmux.cwd"
unset TMUX

# Exercise the real ewt and tmux2, recording tmux calls without touching a server.
cat >"$sandbox/bin/tmux" <<'EOF'
#!/usr/bin/env bash
printf '%s\0' "$@" >>"$TMUX_TEST_LOG"
printf '\0' >>"$TMUX_TEST_LOG"
printf '%s\0' "$PWD" >>"$TMUX_TEST_CWD"
case "$1" in
    has-session) exit "${TMUX_TEST_EXISTS:-1}" ;;
    new-session) exit "${TMUX_TEST_CREATE_STATUS:-0}" ;;
    *) exit "${TMUX_TEST_ACTION_STATUS:-0}" ;;
esac
EOF
chmod +x "$sandbox/bin/tmux"

tests=0
pass() {
    tests=$((tests + 1))
    printf 'ok %d - %s\n' "$tests" "$1"
}
fail() {
    printf 'not ok %d - %s\n' "$((tests + 1))" "$1" >&2
    exit 1
}
reset_log() {
    : >"$TMUX_TEST_LOG"
    : >"$TMUX_TEST_CWD"
}
expect_calls() {
    printf '%s\0' "$@" >"$sandbox/expected"
    cmp -s "$sandbox/expected" "$TMUX_TEST_LOG" || fail 'unexpected tmux arguments'
}
expect_cwd() {
    local directory
    while IFS= read -r -d '' directory; do
        [[ "$directory" == "$1" ]] || fail 'tmux ran outside the target worktree'
    done <"$TMUX_TEST_CWD"
}
expect_failure() {
    if tmux2wt "$@" >"$sandbox/stdout" 2>"$sandbox/stderr"; then
        fail 'invalid invocation succeeded'
    fi
    [[ ! -s "$TMUX_TEST_LOG" ]] || fail 'invalid invocation called tmux'
}

repo="$sandbox/repo root"
feature="$sandbox/feature space.:%\\path"
session='repo root--feat/thing'
git init -q "$repo"
git -C "$repo" symbolic-ref HEAD refs/heads/main
git -C "$repo" -c user.name='Tmux2wt Tests' -c user.email=tmux2wt@example.invalid \
    -c commit.gpgsign=false commit -qm initial --allow-empty
git -C "$repo" worktree add -qb feat/thing "$feature"
git -C "$repo" branch feat/no-worktree
git -C "$repo" worktree add -qb feat/missing "$sandbox/missing"
rm -rf -- "$sandbox/missing"
mkdir -p "$repo/nested/deep" "$feature/nested"
cd "$repo/nested/deep"

reset_log
tmux2wt feat/thing
expect_calls has-session -t "=$session" '' new -s "$session" ''
expect_cwd "$feature"
[[ "$PWD" == "$repo/nested/deep" ]] || fail 'changed caller directory'
pass 'creates a worktree session outside tmux, resolving nested repos and unusual paths'

reset_log
TMUX_TEST_EXISTS=0 tmux2wt feat/thing
expect_calls has-session -t "=$session" '' attach -t "=$session" ''
expect_cwd "$feature"
pass 'attaches to an existing session outside tmux'

reset_log
TMUX=test tmux2wt feat/thing
expect_calls has-session -t "=$session" '' \
    new-session -d -s "$session" -c "$feature" '' switch-client -t "=$session" ''
expect_cwd "$feature"
pass 'creates a detached session and switches the client inside tmux'

reset_log
TMUX=test TMUX_TEST_EXISTS=0 tmux2wt feat/thing
expect_calls has-session -t "=$session" '' switch-client -t "=$session" ''
pass 'reuses the session inside tmux'

reset_log
cd "$feature/nested"
tmux2wt main
expect_calls has-session -t '=repo root--main' '' new -s 'repo root--main' ''
expect_cwd "$repo"
pass 'resolves the main checkout from a linked worktree and includes its branch in the session name'

reset_log
TMUX_TEST_EXISTS=0 tmux2wt feat/thing
expect_calls has-session -t "=$session" '' attach -t "=$session" ''
expect_cwd "$feature"
pass 'uses the same repo and branch session name when called from a linked worktree'

reset_log
git -C "$repo" worktree add -qb feat/with.dot "$sandbox/dotted branch"
tmux2wt feat/with.dot
expect_calls has-session -t '=repo root--feat/with-dot' '' new -s 'repo root--feat/with-dot' ''
expect_cwd "$sandbox/dotted branch"
pass 'preserves branch slashes and replaces dots that tmux reserves'

reset_log
tmux2 "$feature"
expect_calls has-session -t '=feature space---\path' '' new -s 'feature space---\path' ''
expect_cwd "$feature"
pass 'keeps plain tmux2 sessions named after their directory'

reset_log
for branch in '' --unknown feat/unknown feat/no-worktree feat/missing; do
    expect_failure "$branch"
done
expect_failure
expect_failure main extra
pass 'rejects invalid arguments and branches without existing worktrees before calling tmux'

listing="$(tmux2wt --list)"
[[ "$listing" == "$(ewt --list)" ]] || fail 'worktree listing differs from ewt'
cd "$sandbox"
expect_failure main
for option in -h --help; do
    help="$(tmux2wt "$option")"
    [[ "$help" == *'Usage: tmux2wt <branch>'* && "$help" == *'t2wt'* ]] || fail 'incomplete help'
done
[[ ! -s "$TMUX_TEST_LOG" ]] || fail 'listing or help called tmux'
pass 'lists worktrees and provides help, including outside a repository'

cd "$repo"
reset_log
if TMUX=test TMUX_TEST_CREATE_STATUS=1 tmux2wt feat/thing; then
    fail 'session creation failure was ignored'
fi
expect_calls has-session -t "=$session" '' new-session -d -s "$session" -c "$feature" ''
reset_log
result=0
TMUX_TEST_EXISTS=0 TMUX_TEST_ACTION_STATUS=7 tmux2wt main || result=$?
[[ "$result" == 7 ]] || fail 'tmux exit status was not preserved'
pass 'stops on session creation failure and preserves the final tmux exit status'

printf '1..%d\n' "$tests"
