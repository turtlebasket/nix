#!/usr/bin/env zsh

setopt nounset pipefail

if (( $# != 2 )); then
  print -ru2 -- "Usage: ${0:t} /path/to/shared.zsh /path/to/ewt"
  exit 2
fi
shared=${1:A}
ewt_executable=${2:A}
export PATH="${ewt_executable:h}:$PATH"
sandbox=$(mktemp -d "${TMPDIR:-/tmp}/ewt-test.XXXXXX")
trap 'rm -rf -- "$sandbox"' EXIT
sandbox=${sandbox:A}

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export GIT_TERMINAL_PROMPT=0

autoload -Uz compinit
compinit -D
source "$shared"
setopt errexit

integer tests=0
pass() {
  (( ++tests ))
  print -r -- "ok $tests - $1"
}
fail() {
  print -ru2 -- "not ok $((tests + 1)) - $1"
  exit 1
}
assert_eq() {
  [[ "$1" == "$2" ]] || fail "$3 (expected '$1', got '$2')"
}
expect_failure() {
  local message=$1
  shift
  if "$@" >"$sandbox/stdout" 2>"$sandbox/stderr"; then
    fail "$message"
  fi
}

repo="$sandbox/repo root"
git init -q "$repo"
git -C "$repo" symbolic-ref HEAD refs/heads/main
git -C "$repo" -c user.name='EWT Tests' -c user.email=ewt@example.invalid \
  -c commit.gpgsign=false commit -qm initial --allow-empty

# Paths deliberately differ from branch names and the nwt naming convention.
feature="$sandbox/space and \\backslash"$'\nworktree\n'
git -C "$repo" worktree add -qb feat/thing1 "$feature"
git -C "$repo" worktree add -qb feat/thing2 "$sandbox/other feature"
git -C "$repo" worktree add -qb fix/thing1 "$sandbox/fix"
git -C "$repo" branch feat/no-worktree
git -C "$repo" worktree add -q --detach "$sandbox/detached"
git -C "$repo" worktree add -qb feat/missing "$sandbox/missing"
rm -rf -- "$sandbox/missing"
mkdir -p "$repo/nested/deep"

cd "$repo/nested/deep"
[[ -x "$ewt_executable" ]] || fail 'ewt is not executable'
assert_eq "$sandbox/fix" "$("$ewt_executable" fix/thing1)" 'executable returned the wrong path'
assert_eq "$repo/nested/deep" "$PWD" 'executable changed the caller directory'
pass 'executable resolves worktree paths in an arbitrary repository'

ewt feat/thing1
assert_eq "$feature" "$PWD" 'ewt did not change the current shell directory'
pass 'jumps from a nested directory to the registered worktree, preserving unusual paths'

mkdir -p "$feature/nested"
cd "$feature/nested"
ewt fix/thing1
assert_eq "$sandbox/fix" "$PWD" 'could not jump between linked worktrees'
ewt main
assert_eq "$repo" "$PWD" 'could not return to the main checkout'
pass 'jumps between linked worktrees and back to the main checkout'

ewt main
assert_eq "$repo" "$PWD" 'jumping to the current worktree failed'
pass 'accepts the current worktree branch'

expect_failure 'missing arguments should fail' ewt
expect_failure 'empty arguments should fail' ewt ''
expect_failure 'extra arguments should fail' ewt main extra
expect_failure 'unknown options should fail' ewt --unknown
expect_failure 'unknown branches should fail' ewt feat/unknown
expect_failure 'branches without worktrees should fail' ewt feat/no-worktree
expect_failure 'missing worktree directories should fail' ewt feat/missing
assert_eq "$repo" "$PWD" 'failed invocations changed directory'
pass 'rejects invalid arguments and branches without usable worktrees without changing directory'

assert_eq _ewt "${_comps[ewt]}" 'ewt completion was not registered'
# Capture the candidates passed to Zsh; prefix matching is handled by compadd.
typeset -a completion_candidates
compadd() {
  [[ "$1" == -a ]] || fail 'expected completion candidates in an array'
  completion_candidates=("${(@P)2}")
}
integer CURRENT=2
_ewt
completion_candidates=("${(@o)completion_candidates}")
assert_eq $'feat/thing1\nfeat/thing2\nfix/thing1\nmain' \
  "${(F)completion_candidates}" 'completion offered incorrect branches'
cd "$feature/nested"
_ewt
completion_candidates=("${(@o)completion_candidates}")
assert_eq $'feat/thing1\nfeat/thing2\nfix/thing1\nmain' \
  "${(F)completion_candidates}" 'completion failed inside a linked worktree'
CURRENT=3
expect_failure 'extra arguments should not complete' _ewt
pass 'registers completion and offers only existing attached worktree branches'

cd "$repo"
listing=$(ewt --list)
assert_eq "$repo" "$PWD" 'listing worktrees changed directory'
assert_eq 4 "${#${(f)listing}}" 'listing did not return the four existing worktree branches'
help=$(ewt --help)
[[ "$help" == *'ewt - enter worktree'* ]] || fail 'help does not explain the command name'
[[ "$help" == *'Usage: ewt <branch>'* ]] || fail 'help does not document invocation'
[[ "$help" == *'Tab completion'* ]] || fail 'help does not document completion'
assert_eq "$repo" "$PWD" 'help changed directory'
pass 'documents enter worktree, usage, completion, and standalone behavior in command help'

cd "$sandbox"
expect_failure 'outside a repository should fail' ewt main
CURRENT=2
expect_failure 'completion outside a repository should fail' _ewt
assert_eq "$sandbox" "$PWD" 'failure outside a repository changed directory'
ewt --help >/dev/null
pass 'handles use outside a repository and provides help'

print -r -- "1..$tests"
