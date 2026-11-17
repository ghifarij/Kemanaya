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

# The command line is read the way the shell reads it, so only real commands
# are checked and text inside quotes or here-documents is data:
# - `'…'` is literal; `"…"` is literal except `$(…)` and backticks, which run;
# - a here-document body is literal, except `$(…)` and backticks when its
#   delimiter is unquoted;
# - `;`, `&`, `|`, `(`, `)` and newlines separate simple commands, and `#` at
#   the start of a word begins a comment;
# - quotes and backslashes are removed from words (`ma\in`, `"main"`,
#   `m'a'in` → `main`), and an expansion leaves a `$` in its word, so a push
#   whose destination comes from one is refused;
# - strings a shell runs (`sh -c '…'`, `eval '…'`) are checked as command
#   lines of their own.
# Unbalanced quotes or an unterminated here-document are refused.

# Set when a shell runs text this parser cannot see as a command: a shell that
# reads stdin (a here-document, a pipe) or a `-c`/`eval` string that holds an
# expansion. The whole line is then also checked with quotes ignored (FLAT).
OPAQUE_SHELL=0
FLAT=0
START_CWD="$CWD"
# Byte-wise strings keep the scanner fast; every character it acts on is ASCII.
LC_ALL=C
TAB=$'\t'
NL=$'\n'

unparseable() {
  block "the guardrail could not parse this command ($1)."
}

# Checks one simple command. Only the command word is checked, so a commit
# message or grep pattern that mentions `git reset --hard` passes. The command
# word is the first word after `VAR=value` assignments; behind a wrapper that
# runs its arguments (`env`, `xargs`, `{`, `then`, …) it is the first `git`,
# `gh` or shell word.
check_words() {
  local words=("$@")
  local count=$# i=0 wrapped=0
  while [ "$i" -lt "$count" ]; do
    case "${words[$i]}" in
      [A-Za-z_]*=*) ;;
      env | */env | command | builtin | exec | nohup | time | nice | sudo | doas | xargs | timeout | watch | \
        '{' | '!' | if | then | else | elif | do | while | until)
        wrapped=1
        ;;
      *) break ;;
    esac
    i=$((i + 1))
  done
  # In the quote-blind check any word may reach a shell: every command wraps.
  [ "$FLAT" -eq 0 ] || wrapped=1
  if [ "$wrapped" -eq 1 ]; then
    while [ "$i" -lt "$count" ]; do
      case "${words[$i]}" in
        git | */git | gh | */gh | push) break ;;
        eval | sh | */sh | bash | */bash | zsh | */zsh | dash | */dash | ksh | */ksh | source | .)
          [ "$FLAT" -eq 1 ] || break
          ;;
      esac
      i=$((i + 1))
    done
  fi
  [ "$i" -lt "$count" ] || return 0

  local rest=("${words[@]:$((i + 1))}")
  GIT_ARGS=(-C "$CWD")
  PUSH_CFG=()
  case "${words[$i]}" in
    git | */git) check_git "${rest[@]}" ;;
    gh | */gh) check_gh "${rest[@]}" ;;
    # `git` produced by an expansion (`` `echo git` push … ``, `$(which git)
    # push …`, `$GIT push …`) leaves `push` or a `$` word in command position.
    push) check_push "${rest[@]}" ;;
    *'$'*) check_git "${rest[@]}" ;;
    cd | pushd) change_dir "${rest[@]}" ;;
    eval) check_executed "${rest[*]}" ;;
    sh | */sh | bash | */bash | zsh | */zsh | dash | */dash | ksh | */ksh) check_shell "${rest[@]}" ;;
    source | .)
      case "${rest[0]}" in
        "" | - | /dev/* | '<'*) OPAQUE_SHELL=1 ;;
      esac
      ;;
  esac
}

# Arguments after `sh`/`bash`/…: the `-c` string runs as a command line; with
# `-s`, no script, `-` or `/dev/stdin` the shell runs whatever reaches stdin.
check_shell() {
  local arg has_c=0 skip_next=0
  for arg in "$@"; do
    if [ "$skip_next" -eq 1 ]; then
      skip_next=0
      continue
    fi
    case "$arg" in
      -o | +o | -O | +O | --rcfile | --init-file) skip_next=1 ;;
      --*) ;;
      -*c*) has_c=1 ;;
      -*s*) OPAQUE_SHELL=1 ;;
      -* | +*) ;;
      *)
        if [ "$has_c" -eq 1 ]; then
          check_executed "$arg"
        else
          case "$arg" in
            /dev/* | '<'*) OPAQUE_SHELL=1 ;;
          esac
        fi
        return 0
        ;;
    esac
  done
  OPAQUE_SHELL=1
}

# A string that a shell runs. An expansion in it (`$CMD`, `$(…)`, xargs `{}`)
# hides what actually runs, so the line is also checked with quotes ignored.
check_executed() {
  case "$1" in
    *'$'* | *'{}'*) OPAQUE_SHELL=1 ;;
  esac
  check_string "$1"
}

# Parses and checks a whole command line. The scanner works on SRC from POS;
# they are local here, so a nested string gets its own.
check_string() {
  local SRC="$1" POS=0 LEN=${#1}
  scan_commands ""
}

# The helpers below share the scanner's state through bash's dynamic scoping:
# `words` (the simple command so far), `word`/`have_word` (the word so far).
end_word() {
  if [ "$have_word" -eq 1 ]; then
    words+=("$word")
    word=""
    have_word=0
  fi
}

end_command() {
  [ "${#words[@]}" -gt 0 ] || return 0
  # Inside `case … esac` a `)` ends a pattern, not a `$(…)`.
  case "${words[0]}" in
    'case') case_depth=$((case_depth + 1)) ;;
    'esac') [ "$case_depth" -gt 0 ] && case_depth=$((case_depth - 1)) ;;
  esac
  check_words "${words[@]}"
  words=()
}

# Scans commands until the end of SRC, or until the `)` that closes a `$(`
# when $1 is ")".
scan_commands() {
  local stop="$1" c next rest depth=0 case_depth=0
  local words=() word="" have_word=0
  local hd_delims=() hd_quoted=() hd_strip=()
  while [ "$POS" -lt "$LEN" ]; do
    c=${SRC:POS:1}
    case "$c" in
      ' ' | "$TAB") end_word ;;
      "$NL")
        end_word
        end_command
        POS=$((POS + 1))
        read_heredocs
        continue
        ;;
      ';' | '&' | '|') end_word; end_command ;;
      '(') end_word; end_command; depth=$((depth + 1)) ;;
      ')')
        end_word
        end_command
        if [ "$depth" -gt 0 ]; then
          depth=$((depth - 1))
        elif [ "$stop" = ")" ] && [ "$case_depth" -eq 0 ]; then
          POS=$((POS + 1))
          [ "${#hd_delims[@]}" -eq 0 ] || unparseable "unterminated here-document"
          return 0
        fi
        ;;
      "'")
        rest=${SRC:POS+1}
        case "$rest" in
          *"'"*) ;;
          *) unparseable "unclosed quote" ;;
        esac
        rest=${rest%%"'"*}
        word+=$rest
        have_word=1
        POS=$((POS + ${#rest} + 2))
        continue
        ;;
      '"')
        have_word=1
        POS=$((POS + 1))
        scan_double quoted
        continue
        ;;
      '\')
        next=${SRC:POS+1:1}
        # A backslash-newline joins lines, as the shell does.
        [ "$next" = "$NL" ] || { word+=${next:-\\}; have_word=1; }
        POS=$((POS + 2))
        continue
        ;;
      '`')
        word+='$'
        have_word=1
        POS=$((POS + 1))
        scan_backtick 0
        continue
        ;;
      '$')
        word+='$'
        have_word=1
        next=${SRC:POS+1:1}
        if [ "$next" = "(" ]; then
          POS=$((POS + 2))
          scan_commands ")"
          continue
        elif [ "$next" = "'" ]; then
          POS=$((POS + 2))
          scan_ansi
          continue
        fi
        ;;
      '#')
        if [ "$have_word" -eq 0 ]; then
          rest=${SRC:POS}
          rest=${rest%%"$NL"*}
          POS=$((POS + ${#rest}))
          continue
        fi
        word+=$c
        ;;
      '<')
        if [ "${SRC:POS+1:1}" = "<" ]; then
          end_word
          if [ "${SRC:POS+2:1}" = "<" ]; then
            POS=$((POS + 3))
          else
            POS=$((POS + 2))
            parse_heredoc_operator
          fi
          continue
        fi
        word+=$c
        have_word=1
        ;;
      *)
        word+=$c
        have_word=1
        ;;
    esac
    POS=$((POS + 1))
  done
  end_word
  end_command
  [ "${#hd_delims[@]}" -eq 0 ] || unparseable "unterminated here-document"
  [ -z "$stop" ] || unparseable "unclosed \$("
}

# Inside `"…"` (or an unquoted here-document body, when $1 is "heredoc"):
# literal text, except `$(…)` and backticks.
scan_double() {
  local c next
  while [ "$POS" -lt "$LEN" ]; do
    c=${SRC:POS:1}
    case "$c" in
      '"')
        if [ "$1" != heredoc ]; then
          POS=$((POS + 1))
          return 0
        fi
        word+=$c
        ;;
      '\')
        next=${SRC:POS+1:1}
        case "$next" in
          "$NL") POS=$((POS + 2)); continue ;;
          '$' | '`' | '"' | '\') word+=$next; POS=$((POS + 2)); continue ;;
        esac
        word+=$c
        ;;
      '$')
        word+=$c
        if [ "${SRC:POS+1:1}" = "(" ]; then
          POS=$((POS + 2))
          scan_commands ")"
          continue
        fi
        ;;
      '`')
        word+='$'
        POS=$((POS + 1))
        scan_backtick 1
        continue
        ;;
      *) word+=$c ;;
    esac
    POS=$((POS + 1))
  done
  [ "$1" = heredoc ] || unparseable "unclosed double quote"
}

# A backtick substitution: the text up to the closing backtick, with `\\`,
# `` \` `` and `\$` (and `\"` inside double quotes) unescaped, runs as a
# command line.
scan_backtick() {
  local c next inner=""
  while [ "$POS" -lt "$LEN" ]; do
    c=${SRC:POS:1}
    case "$c" in
      '`')
        POS=$((POS + 1))
        check_string "$inner"
        return 0
        ;;
      '\')
        next=${SRC:POS+1:1}
        case "$next" in
          '$' | '`' | '\') inner+=$next ;;
          '"') if [ "$1" -eq 1 ]; then inner+=$next; else inner+=$c$next; fi ;;
          *) inner+=$c$next ;;
        esac
        POS=$((POS + 2))
        continue
        ;;
      *) inner+=$c ;;
    esac
    POS=$((POS + 1))
  done
  unparseable "unclosed backtick"
}

# `$'…'`: literal, but a backslash escapes the next character, `\'` included.
scan_ansi() {
  local c
  while [ "$POS" -lt "$LEN" ]; do
    c=${SRC:POS:1}
    case "$c" in
      "'") POS=$((POS + 1)); return 0 ;;
      '\') word+=${SRC:POS:2}; POS=$((POS + 2)); continue ;;
      *) word+=$c ;;
    esac
    POS=$((POS + 1))
  done
  unparseable "unclosed quote"
}

# `<<WORD`, `<<-WORD`, `<<'WORD'`: notes the delimiter; the body starts after
# the next newline.
parse_heredoc_operator() {
  local c delimiter="" quoted=0 strip=0
  if [ "${SRC:POS:1}" = "-" ]; then
    strip=1
    POS=$((POS + 1))
  fi
  while [ "${SRC:POS:1}" = " " ] || [ "${SRC:POS:1}" = "$TAB" ]; do
    POS=$((POS + 1))
  done
  while [ "$POS" -lt "$LEN" ]; do
    c=${SRC:POS:1}
    case "$c" in
      ' ' | "$TAB" | "$NL" | ';' | '&' | '|' | '(' | ')' | '<' | '>') break ;;
      "'" | '"') quoted=1 ;;
      '\') quoted=1; POS=$((POS + 1)); delimiter+=${SRC:POS:1} ;;
      *) delimiter+=$c ;;
    esac
    POS=$((POS + 1))
  done
  [ -n "$delimiter" ] || unparseable "here-document without a delimiter"
  hd_delims+=("$delimiter")
  hd_quoted+=("$quoted")
  hd_strip+=("$strip")
}

# At a newline, consumes the bodies of the pending here-documents. A body is
# data; with an unquoted delimiter its `$(…)` and backticks still run.
read_heredocs() {
  local n=0 line rest body
  while [ "$n" -lt "${#hd_delims[@]}" ]; do
    body=""
    while :; do
      [ "$POS" -lt "$LEN" ] || unparseable "unterminated here-document"
      rest=${SRC:POS}
      line=${rest%%"$NL"*}
      POS=$((POS + ${#line} + 1))
      if [ "${hd_strip[$n]}" -eq 1 ]; then
        while [ "${line#"$TAB"}" != "$line" ]; do line=${line#"$TAB"}; done
      fi
      [ "$line" = "${hd_delims[$n]}" ] && break
      body+=$line$NL
    done
    [ "${hd_quoted[$n]}" -eq 1 ] || check_expansions "$body"
    n=$((n + 1))
  done
  hd_delims=()
  hd_quoted=()
  hd_strip=()
}

check_expansions() {
  local SRC="$1" POS=0 LEN=${#1} word="" have_word=0
  scan_double heredoc
}

# The quote-blind check: `; & | ( )`, backticks and `$(` split the line and
# every quote and backslash is dropped, so any text that could reach a shell
# is checked as a command. Used only when OPAQUE_SHELL is set.
check_flat() {
  local text normalized segment
  local words=()
  FLAT=1
  CWD="$START_CWD"
  SWITCHES_TO_PROTECTED=0
  text=${COMMAND//"\\$NL"/}
  # Drop a trailing ` # comment`, unless it holds quotes or separators.
  text=$(printf '%s\n' "$text" | sed -E "s/(^|[[:space:]])#[^\"'\`\$;&|()\\\\]*\$//")
  text=${text//\`/ \$ ;}
  normalized=$(printf '%s\n' "$text" | tr ';&|()' '\n\n\n\n\n' | tr -d "\"'\\\\")
  while IFS= read -r segment; do
    words=()
    read -ra words <<<"$segment"
    [ "${#words[@]}" -eq 0 ] || check_words "${words[@]}"
  done <<<"$normalized"
}

check_string "$COMMAND"
[ "$OPAQUE_SHELL" -eq 0 ] || check_flat

exit 0
