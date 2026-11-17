#!/bin/bash
# Claude Code PreToolUse hook for the Bash tool (D-034).
#
# `main` only changes through PRs that the user reviews and merges, so this
# blocks: pushes that land on `main`, force pushes, merging a PR on the user's
# behalf (`gh pr merge`, the merge API), and git commands that throw away work.
# Feature-branch pushes pass through.
#
# Exit 2 = block (stderr is shown to Claude); exit 0 = allow.
# This is the local half of the protection; GitHub branch protection is the other.
# Runs on macOS's bash 3.2 with only jq and POSIX tools.

PROTECTED_BRANCH="main"

INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  # Without jq the command cannot be parsed: refuse anything that might push.
  if printf '%s' "$INPUT" | grep -qE 'push|merge'; then
    echo "BLOCKED: jq is not installed, so the git guardrail cannot inspect this command." >&2
    exit 2
  fi
  exit 0
fi

block() {
  echo "BLOCKED: $1 The user has prevented you from doing this (D-034: \`$PROTECTED_BRANCH\` changes only through PRs the user merges)." >&2
  exit 2
}

# A payload that is not a JSON object cannot be inspected, so it is refused.
# A valid payload without a command (another tool) passes through.
if ! printf '%s' "$INPUT" | jq -e 'type == "object"' >/dev/null 2>&1; then
  block "the guardrail could not parse its input."
fi
if ! COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null); then
  block "the guardrail could not parse its input."
fi
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -n "$CWD" ] || CWD="${CLAUDE_PROJECT_DIR:-.}"

# --- Helpers ------------------------------------------------------------------

# True when a branch or ref name means the protected branch. Folds case,
# repeated slashes, `refs/`, `heads/`/`remotes/` and `~N`/`^N` suffixes, so
# `refs/heads//MAIN` and `main~0` count too.
is_protected() {
  local name
  name=$(printf '%s' "$1" | tr -s '/' | tr '[:upper:]' '[:lower:]')
  name="${name#refs/}"
  name="${name#heads/}"
  name="${name#remotes/}"
  name="${name%%[~^#]*}"
  [ "$name" = "$PROTECTED_BRANCH" ]
}

# True when a push refspec names the protected branch as its destination.
targets_protected() {
  local spec="${1#+}"
  # A lone `:` pushes every matching branch, the protected one included.
  [ "$spec" = ":" ] && return 0
  local destination="${spec##*:}"
  case "$spec" in
    # `x:HEAD` writes to whatever the remote's HEAD points at.
    *:*) case "$destination" in HEAD | @) return 0 ;; esac ;;
  esac
  is_protected "$destination"
}

# Set per git command: `-C`/`--git-dir` to find the right repository, and a
# command-line `push.default` so it is honoured when resolving the destination.
GIT_ARGS=()
PUSH_CFG=()

current_branch() {
  git "${GIT_ARGS[@]}" symbolic-ref --quiet --short HEAD 2>/dev/null
}

# `cd`/`pushd` earlier in the command line move where `git push` runs.
change_dir() {
  local arg dir=""
  for arg in "$@"; do
    case "$arg" in
      -) return 0 ;;
      -*) ;;
      *) dir="$arg"; break ;;
    esac
  done
  case "$dir" in
    "" | "~") dir="$HOME" ;;
    "~/"*) dir="$HOME/${dir#"~/"}" ;;
    /*) ;;
    *) dir="$CWD/$dir" ;;
  esac
  CWD="$dir"
}

# --- Pushes -------------------------------------------------------------------

# Inspects the arguments that follow `git push`.
check_push() {
  local positional=()
  local arg flags
  local skip_next=0 options_done=0
  for arg in "$@"; do
    if [ "$skip_next" -eq 1 ]; then
      skip_next=0
      continue
    fi
    case "$arg" in
      *'$'* | *'{'* | *'}'* | *'*'* | *'?'* | *'['* | *']'*)
        block "the push argument '$arg' is expanded by the shell, so the guardrail cannot verify the destination."
        ;;
      # Redirections: `>`, `2>`, `>>` take the next word as a file. A `<`
      # operand stays a positional, since `xargs` may turn it into a refspec.
      *'>') skip_next=1; continue ;;
      *'>'* | '<'* | [0-9]'<'*) continue ;;
      +*) block "'$arg' is a force-push refspec." ;;
      "") continue ;;
    esac

    if [ "$options_done" -eq 1 ]; then
      positional+=("$arg")
      continue
    fi
    # git accepts any unique prefix of a long option (`--al` = `--all`), so
    # the dangerous ones are matched by prefix.
    case "$arg" in
      --) options_done=1 ;;
      --for* | --al* | --b* | --mi* | --pru*)
        block "'git push $arg' can overwrite or push \`$PROTECTED_BRANCH\`."
        ;;
      # Options whose value is the next word (`-o X`, `--repo X`, …).
      --pu* | --rep* | --rec* | --e*)
        [ "${arg#*=}" = "$arg" ] && skip_next=1
        ;;
      --*) ;;
      -*)
        # Short-option cluster: `f` forces; `o` takes the rest or the next word.
        flags="${arg#-}"
        while [ -n "$flags" ]; do
          case "$flags" in
            f*) block "'git push $arg' is a force push." ;;
            o) skip_next=1; break ;;
            o*) break ;;
          esac
          flags="${flags#?}"
        done
        ;;
      *) positional+=("$arg") ;;
    esac
  done

  # positional[0] is the remote; the rest are refspecs.
  local uses_current_branch=0
  if [ "${#positional[@]}" -le 1 ]; then
    uses_current_branch=1
  fi

  local refspec
  for refspec in "${positional[@]:1}"; do
    if targets_protected "$refspec"; then
      block "this pushes to \`$PROTECTED_BRANCH\`."
    fi
    case "$refspec" in
      HEAD | @) uses_current_branch=1 ;;
    esac
  done

  if [ "$uses_current_branch" -eq 1 ]; then
    if [ "$SWITCHES_TO_PROTECTED" -eq 1 ] || is_protected "$(current_branch)"; then
      block "this pushes the current branch, which is \`$PROTECTED_BRANCH\`. Work on a feat/, fix/ or chore/ branch and open a PR."
    fi
  fi

  # Without a refspec, git's config decides the destination.
  if [ "${#positional[@]}" -le 1 ]; then
    local mode destination
    mode=$(git "${GIT_ARGS[@]}" "${PUSH_CFG[@]}" config --get push.default 2>/dev/null)
    if [ "$mode" = "matching" ]; then
      block "push.default=matching pushes every matching branch, \`$PROTECTED_BRANCH\` included."
    fi
    destination=$(git "${GIT_ARGS[@]}" "${PUSH_CFG[@]}" rev-parse --abbrev-ref --symbolic-full-name '@{push}' 2>/dev/null)
    if [ -n "$destination" ] && is_protected "${destination#*/}"; then
      block "the current branch is configured to push to \`$PROTECTED_BRANCH\`."
    fi
  fi
}

# --- Commands that discard work or merge on the user's behalf -----------------

# `git checkout -b x`, `git switch -c main`, `git switch main`: notes whether an
# earlier command in the line moves onto the protected branch before a push.
SWITCHES_TO_PROTECTED=0
note_switch() {
  local arg first="" created="" next_is_name=0 paths=0 track=0
  for arg in "$@"; do
    if [ "$next_is_name" -eq 1 ]; then
      created="$arg"
      next_is_name=0
      continue
    fi
    case "$arg" in
      --) paths=1; break ;;
      -b | -B | -c | -C | --orphan | --cr* | --force-c*) next_is_name=1 ;;
      -b?* | -B?* | -c?* | -C?*) created="${arg#-?}" ;;
      -t | --tr*) track=1 ;;
      -*) ;;
      *) [ -n "$first" ] || first="$arg" ;;
    esac
  done
  # `git checkout main -- file` restores a file; it does not switch.
  if [ -z "$created" ] && [ "$paths" -eq 1 ]; then
    return 0
  fi
  local target="${created:-$first}"
  # `--track origin/main` creates and switches to a local `main`.
  [ "$track" -eq 1 ] && [ -z "$created" ] && target="${target##*/}"
  if is_protected "$target"; then
    SWITCHES_TO_PROTECTED=1
  fi
}

# `git checkout .` / `git restore .`: discard every uncommitted change.
# `git restore --staged .` only unstages, so it passes.
check_discard() {
  local subcommand="$1"
  shift
  local arg staged=0 worktree=0 everything=0
  for arg in "$@"; do
    case "$arg" in
      --st*) staged=1 ;;
      --w*) worktree=1 ;;
      --*) ;;
      -*)
        case "$arg" in *S*) staged=1 ;; esac
        case "$arg" in *W*) worktree=1 ;; esac
        ;;
      . | ./ | .. | ../ | :/ | :/:) everything=1 ;;
    esac
  done
  [ "$everything" -eq 1 ] || return 0
  if [ "$subcommand" = "restore" ] && [ "$staged" -eq 1 ] && [ "$worktree" -eq 0 ]; then
    return 0
  fi
  block "'git $subcommand' on the whole tree discards uncommitted work."
}

check_reset() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --) break ;;
      --ha*) block "'git reset --hard' discards uncommitted work." ;;
    esac
  done
}

check_clean() {
  local arg flags
  for arg in "$@"; do
    case "$arg" in
      --) break ;;
      --f*) block "'git clean --force' deletes untracked files." ;;
      --*) ;;
      -*)
        # `-e` takes the rest of the cluster as a pattern.
        flags="${arg#-}"
        flags="${flags%%e*}"
        case "$flags" in
          *f*) block "'git clean $arg' deletes untracked files." ;;
        esac
        ;;
    esac
  done
}

check_branch() {
  local arg delete=0 force=0
  for arg in "$@"; do
    case "$arg" in
      --) break ;;
      --del*) delete=1 ;;
      --forc*) force=1 ;;
      --*) ;;
      -*)
        case "$arg" in *D*) block "'git branch $arg' deletes a branch that may hold unmerged work." ;; esac
        case "$arg" in *d*) delete=1 ;; esac
        case "$arg" in *f*) force=1 ;; esac
        ;;
    esac
  done
  if [ "$delete" -eq 1 ] && [ "$force" -eq 1 ]; then
    block "a forced 'git branch' delete drops a branch that may hold unmerged work."
  fi
}

# Arguments that follow `git`: its own options, then the subcommand.
check_git() {
  local setting
  while [ $# -gt 0 ]; do
    case "$1" in
      -C) GIT_ARGS+=(-C "$2"); shift 2 2>/dev/null || shift ;;
      -C?*) GIT_ARGS+=(-C "${1#-C}"); shift ;;
      --git-dir) GIT_ARGS+=("--git-dir=$2"); shift 2 2>/dev/null || shift ;;
      --git-dir=*) GIT_ARGS+=("$1"); shift ;;
      -c | -c?*)
        if [ "$1" = "-c" ]; then
          setting="$2"
          shift 2 2>/dev/null || shift
        else
          setting="${1#-c}"
          shift
        fi
        case "$(printf '%s' "$setting" | tr '[:upper:]' '[:lower:]')" in
          alias.*) block "a command-line alias ('git -c $setting') hides which git command runs." ;;
          push.default=*) PUSH_CFG=(-c "push.default=${setting#*=}") ;;
        esac
        ;;
      --work-tree | --namespace | --config-env | --super-prefix | --attr-source) shift 2 2>/dev/null || shift ;;
      -*) shift ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return 0

  local subcommand="$1"
  shift
  case "$subcommand" in
    push) check_push "$@" ;;
    reset) check_reset "$@" ;;
    clean) check_clean "$@" ;;
    branch) check_branch "$@" ;;
    checkout) check_discard checkout "$@"; note_switch "$@" ;;
    restore) check_discard restore "$@" ;;
    switch) note_switch "$@" ;;
    stash)
      case "$1" in
        drop | clear) block "'git stash $1' throws away stashed work." ;;
      esac
      ;;
  esac
}

# Arguments that follow `gh`.
check_gh() {
  local positional=()
  local arg
  local skip_next=0
  for arg in "$@"; do
    if [ "$skip_next" -eq 1 ]; then
      skip_next=0
      continue
    fi
    case "$arg" in
      -R | --repo) skip_next=1 ;;
      -*) ;;
      *) positional+=("$arg") ;;
    esac
  done

  if [ "${positional[0]}" = "pr" ] && [ "${positional[1]}" = "merge" ]; then
    block "'gh pr merge' merges on the user's behalf."
  fi
  if [ "${positional[0]}" = "api" ]; then
    for arg in "$@"; do
      case "$arg" in
        */merge* | *[mM]ergePullRequest* | *AutoMerge*)
          block "this GitHub API call merges on the user's behalf."
          ;;
      esac
    done
  fi
}

# --- Command line -------------------------------------------------------------

# Normalise the command line so quoting tricks cannot hide a command:
# - join `\`-newline continuations, as the shell does;
# - drop a trailing ` # comment`, unless it holds quotes or separators that
#   could make it something else;
# - backticks and `$(` become separators, and a `$` word marks the substitution
#   so a push whose destination comes from one is refused;
# - `; & | ( )` and newlines separate simple commands;
# - quotes and backslashes are removed (`ma\in`, `"main"`, `m'a'in` → `main`).
# Quotes are not parsed, so text inside a string (`sh -c "…"`, `eval "…"`)
# is checked as if it were a command: the hook errs on the side of blocking.
BS_NL=$'\\\n'
TEXT=${COMMAND//"$BS_NL"/}
TEXT=$(printf '%s\n' "$TEXT" | sed -E "s/(^|[[:space:]])#[^\"'\`\$;&|()\\\\]*\$//")
TEXT=${TEXT//\`/ \$ ;}
NORMALIZED=$(printf '%s\n' "$TEXT" | tr ';&|()' '\n\n\n\n\n' | tr -d "\"'\\\\")

# Only the command word of each simple command is checked, so a commit message
# or grep pattern that mentions `git reset --hard` passes. The command word is
# the first word after `VAR=value` assignments; behind a wrapper that runs its
# arguments (`env`, `sh -c`, `eval`, `xargs`, `{`, `then`, …) it is the first
# `git` or `gh` word.
while IFS= read -r segment; do
  words=()
  read -ra words <<<"$segment"
  count=${#words[@]}
  i=0
  wrapped=0
  while [ "$i" -lt "$count" ]; do
    case "${words[$i]}" in
      [A-Za-z_]*=*) ;;
      env | */env | command | builtin | exec | eval | nohup | time | nice | sudo | doas | xargs | timeout | watch | \
        sh | */sh | bash | */bash | zsh | */zsh | dash | ksh | '{' | '!' | if | then | else | elif | do | while | until)
        wrapped=1
        ;;
      *) break ;;
    esac
    i=$((i + 1))
  done
  if [ "$wrapped" -eq 1 ]; then
    while [ "$i" -lt "$count" ]; do
      case "${words[$i]}" in
        git | */git | gh | */gh | push) break ;;
      esac
      i=$((i + 1))
    done
  fi
  [ "$i" -lt "$count" ] || continue

  GIT_ARGS=(-C "$CWD")
  PUSH_CFG=()
  case "${words[$i]}" in
    git | */git) check_git "${words[@]:$((i + 1))}" ;;
    gh | */gh) check_gh "${words[@]:$((i + 1))}" ;;
    # `git` produced by a substitution: `` `echo git` push … ``, `$(which git) push …`.
    push) check_push "${words[@]:$((i + 1))}" ;;
    cd | pushd) change_dir "${words[@]:$((i + 1))}" ;;
  esac
done <<<"$NORMALIZED"

exit 0
