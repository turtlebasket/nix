#!/usr/bin/env bash

set -euo pipefail

nwt="${1:-}"
[[ -n "$nwt" ]] || {
    printf 'Usage: %s /path/to/nwt\n' "${0##*/}" >&2
    exit 2
}
nwt="$(cd "$(dirname "$nwt")" && pwd -P)/$(basename "$nwt")"

sandbox="$(mktemp -d "${TMPDIR:-/tmp}/nwt-test.XXXXXX")"
[[ -n "$sandbox" && "$sandbox" != "/" ]] || exit 1
trap 'rm -rf "$sandbox"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null
export GIT_CONFIG_NOSYSTEM=1
export GIT_TERMINAL_PROMPT=0
export HOME="$sandbox/home"
mkdir -p "$HOME"

tests=0

pass() {
    tests=$((tests + 1))
    printf 'ok %d - %s\n' "$tests" "$1"
}

fail() {
    printf 'not ok %d - %s\n' "$((tests + 1))" "$1" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    [[ "$actual" == "$expected" ]] || fail "$message (expected '$expected', got '$actual')"
}

assert_file() {
    [[ -f "$1" ]] || fail "$2"
}

assert_no_path() {
    [[ ! -e "$1" && ! -L "$1" ]] || fail "$2"
}

assert_branch_absent() {
    if git -C "$1" show-ref --verify --quiet "refs/heads/$2"; then
        fail "$3"
    fi
}

expect_failure() {
    local message="$1"
    shift
    if "$@" >"$sandbox/stdout" 2>"$sandbox/stderr"; then
        fail "$message"
    fi
}

run_in() {
    local directory="$1"
    shift
    (
        cd "$directory"
        "$@"
    )
}

init_repo() {
    local repo="$1"
    mkdir -p "$repo"
    git init -q "$repo"
    git -C "$repo" symbolic-ref HEAD refs/heads/main
    git -C "$repo" config user.name 'NWT Tests'
    git -C "$repo" config user.email 'nwt-tests@example.invalid'
    printf 'initial\n' >"$repo/tracked.txt"
    git -C "$repo" add tracked.txt
    git -C "$repo" commit -qm 'initial'
}

commit_file() {
    local repo="$1"
    local contents="$2"
    local message="$3"
    printf '%s\n' "$contents" >"$repo/tracked.txt"
    git -C "$repo" add tracked.txt
    git -C "$repo" commit -qm "$message"
}

basic_repo="$sandbox/basic parent/repo root"
init_repo "$basic_repo"
mkdir -p "$basic_repo/a/deep/subdir"
basic_head="$(git -C "$basic_repo" rev-parse HEAD)"
printf 'dirty\n' >>"$basic_repo/tracked.txt"
printf 'untracked\n' >"$basic_repo/untracked.txt"
(
    cd "$basic_repo/a/deep/subdir"
    "$nwt" feat/my-label >/dev/null
)
basic_target="${basic_repo}+feat+my-label"
assert_file "$basic_target/tracked.txt" 'basic worktree was not created at the encoded sibling path'
assert_eq feat/my-label "$(git -C "$basic_target" branch --show-current)" 'basic worktree has the wrong branch'
assert_eq "$basic_head" "$(git -C "$basic_target" rev-parse HEAD)" 'basic worktree has the wrong starting commit'
assert_eq initial "$(sed -n '1p' "$basic_target/tracked.txt")" 'dirty tracked changes leaked into the new worktree'
assert_no_path "$basic_target/untracked.txt" 'untracked files leaked into the new worktree'
pass 'creates an encoded sibling worktree from a nested directory and current HEAD'

local_repo="$sandbox/local-source"
init_repo "$local_repo"
git -C "$local_repo" switch -qc base/local
commit_file "$local_repo" local-base 'local base'
local_head="$(git -C "$local_repo" rev-parse HEAD)"
git -C "$local_repo" switch -q main
(
    cd "$local_repo"
    "$nwt" fix/from-local --from-branch base/local >/dev/null
)
local_target="${local_repo}+fix+from-local"
assert_eq "$local_head" "$(git -C "$local_target" rev-parse HEAD)" '--from-branch did not use the local branch'
assert_eq main "$(git -C "$local_repo" branch --show-current)" '--from-branch changed the source worktree branch'
pass 'starts from a local branch without changing the source worktree'

detached_repo="$sandbox/detached"
init_repo "$detached_repo"
detached_head="$(git -C "$detached_repo" rev-parse HEAD)"
git -C "$detached_repo" switch -q --detach
(
    cd "$detached_repo"
    "$nwt" chore/from-detached >/dev/null
)
assert_eq "$detached_head" "$(git -C "${detached_repo}+chore+from-detached" rev-parse HEAD)" 'detached HEAD was not used as the default source'
pass 'uses the current commit when the source worktree has detached HEAD'

linked_repo="$sandbox/linked-main"
linked_source="$sandbox/linked source"
init_repo "$linked_repo"
git -C "$linked_repo" worktree add -qb source/linked "$linked_source"
commit_file "$linked_source" linked-base 'linked base'
linked_head="$(git -C "$linked_source" rev-parse HEAD)"
mkdir -p "$linked_source/nested"
(
    cd "$linked_source/nested"
    "$nwt" feat/linked-child >/dev/null
)
assert_eq "$linked_head" "$(git -C "${linked_source}+feat+linked-child" rev-parse HEAD)" 'linked worktree HEAD was not used as the source'
pass 'works from a subdirectory of a linked worktree'

remote_bare="$sandbox/remote.git"
remote_seed="$sandbox/remote-seed"
remote_clone="$sandbox/remote-clone"
git init -q --bare "$remote_bare"
init_repo "$remote_seed"
git -C "$remote_seed" remote add origin "$remote_bare"
git -C "$remote_seed" push -q origin main
git -C "$remote_seed" switch -qc remote/base
commit_file "$remote_seed" remote-base 'remote base'
remote_head="$(git -C "$remote_seed" rev-parse HEAD)"
git -C "$remote_seed" push -q origin remote/base
git -C "$remote_bare" symbolic-ref HEAD refs/heads/main
git clone -q "$remote_bare" "$remote_clone"

git -C "$remote_clone" branch --track remote/base origin/remote/base >/dev/null
git -C "$remote_clone" branch -D remote/base >/dev/null
(
    cd "$remote_clone"
    "$nwt" feat/from-remote --from-branch remote/base >/dev/null
)
assert_eq "$remote_head" "$(git -C "${remote_clone}+feat+from-remote" rev-parse HEAD)" 'remote-tracking branch was not used after deleting the local branch'
pass 'starts from a remote branch whose local branch was deleted'

git -C "$remote_seed" switch -qc remote/fresh
commit_file "$remote_seed" remote-fresh 'fresh remote base'
fresh_remote_head="$(git -C "$remote_seed" rev-parse HEAD)"
git -C "$remote_seed" push -q origin remote/fresh
(
    cd "$remote_clone"
    "$nwt" --from-branch=remote/fresh feat/fetched-remote >/dev/null
)
assert_eq "$fresh_remote_head" "$(git -C "${remote_clone}+feat+fetched-remote" rev-parse HEAD)" 'previously unseen remote branch was not fetched'
pass 'finds and fetches a remote branch whose objects and refs do not exist locally'

git -C "$remote_clone" update-ref -d refs/remotes/origin/remote/base
git -C "$remote_clone" remote add backup "$remote_bare"
expect_failure 'an unqualified branch on multiple remotes should be rejected' \
    run_in "$remote_clone" "$nwt" feat/ambiguous --from-branch remote/base
assert_branch_absent "$remote_clone" feat/ambiguous 'ambiguous remote resolution created a branch'
assert_no_path "${remote_clone}+feat+ambiguous" 'ambiguous remote resolution created a worktree path'
(
    cd "$remote_clone"
    "$nwt" feat/qualified --from-branch origin/remote/base >/dev/null
)
assert_eq "$remote_head" "$(git -C "${remote_clone}+feat+qualified" rev-parse HEAD)" 'qualified remote branch resolved incorrectly'
pass 'rejects ambiguous remotes and accepts a qualified remote branch'

errors_repo="$sandbox/errors"
init_repo "$errors_repo"

expect_failure 'no arguments should fail' run_in "$errors_repo" "$nwt"
expect_failure 'unknown options should fail' run_in "$errors_repo" "$nwt" --wat feat/x
expect_failure 'a missing --from-branch value should fail' run_in "$errors_repo" "$nwt" --from-branch
expect_failure 'duplicate --from-branch options should fail' run_in "$errors_repo" "$nwt" --from-branch main --from-branch main feat/x
expect_failure 'extra branch arguments should fail' run_in "$errors_repo" "$nwt" feat/x feat/y
expect_failure 'invalid new branch names should fail' run_in "$errors_repo" "$nwt" bad..branch
expect_failure 'invalid source branch names should fail' run_in "$errors_repo" "$nwt" feat/x --from-branch bad..branch
expect_failure 'unknown source branches should fail' run_in "$errors_repo" "$nwt" feat/x --from-branch absent
expect_failure 'running outside a repository should fail' run_in "$sandbox" "$nwt" feat/x
expect_failure 'running in a bare repository should fail' run_in "$remote_bare" "$nwt" feat/x
assert_branch_absent "$errors_repo" feat/x 'invalid invocation created a branch'
pass 'rejects malformed invocations, invalid refs, missing sources, and non-worktrees'

git -C "$errors_repo" branch feat/existing
expect_failure 'an existing target branch should fail' run_in "$errors_repo" "$nwt" feat/existing
assert_no_path "${errors_repo}+feat+existing" 'existing branch failure created a worktree path'

collision_target="${errors_repo}+fix+collision"
mkdir -p "$collision_target"
expect_failure 'an existing target directory should fail' run_in "$errors_repo" "$nwt" fix/collision
assert_branch_absent "$errors_repo" fix/collision 'target directory collision created a branch'

broken_target="${errors_repo}+fix+broken-link"
ln -s nowhere "$broken_target"
expect_failure 'a dangling symlink target should fail' run_in "$errors_repo" "$nwt" fix/broken-link
assert_branch_absent "$errors_repo" fix/broken-link 'dangling symlink collision created a branch'
pass 'does not alter the repository when branches or target paths collide'

encoding_repo="$sandbox/encoding-collision"
init_repo "$encoding_repo"
(
    cd "$encoding_repo"
    "$nwt" feat/a >/dev/null
)
expect_failure 'branch names with colliding path encodings should fail' \
    run_in "$encoding_repo" "$nwt" 'feat+a'
assert_branch_absent "$encoding_repo" feat+a 'an encoded target collision created the second branch'
pass 'rejects branch names whose slash encoding collides with an existing worktree'

unborn_repo="$sandbox/unborn"
git init -q "$unborn_repo"
expect_failure 'an unborn HEAD should fail' run_in "$unborn_repo" "$nwt" feat/x
assert_branch_absent "$unborn_repo" feat/x 'unborn HEAD failure created a branch'
assert_no_path "${unborn_repo}+feat+x" 'unborn HEAD failure created a worktree path'
pass 'rejects an unborn source repository without side effects'

"$nwt" --help >/dev/null
pass 'provides help without requiring a Git repository'

printf '1..%d\n' "$tests"
