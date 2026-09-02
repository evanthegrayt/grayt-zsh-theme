##
# @file grayt-repo-refresh.zsh
# @description Optional idle prompt refreshes for Git repositories.
#
# This helper makes the prompt redraw while zsh is sitting idle at an existing
# prompt. Normally, grayt only recalculates Git state when zsh renders a fresh
# prompt, which means another terminal can change the repository without this
# terminal noticing until the next command runs.
#
# When `GRAYT_REPO_REFRESH` is enabled and `fswatch` is installed, the helper
# registers a `precmd` hook that checks the current directory. If the shell is
# inside a Git worktree, it starts one background `fswatch` process for that
# repository. The watcher writes batched change notifications into a FIFO. zsh's
# line editor watches the read end of that FIFO with `zle -F`; when data is
# available, `__grayt_repo_refresh_on_event` drains the pending batch and asks
# zsh to redraw the prompt with `zle .reset-prompt`.
#
# Branch switches use this same path. Git updates files such as `HEAD`, refs,
# the index, or packed refs during checkout/switch operations; the watcher does
# not need to know which kind of repository change happened because the prompt
# recomputes branch and dirty state after the redraw.
#
# The helper watches the worktree root, plus external Git directories when Git
# reports them. That covers normal repositories, linked worktrees, and setups
# where `.git` points outside the worktree. Some noisy Git internals are filtered
# out before events reach zsh, such as object writes, reflog writes, lock files,
# and `COMMIT_EDITMSG`.
#
# The helper does not render any prompt text or cache Git status.
# It only decides whether a repository should be watched and requests a redraw
# after filesystem changes. That boundary should make it easy to split this file
# into a standalone zsh plugin later.
#
# @env GRAYT_REPO_REFRESH Enables repo refresh when set to `1`, `true`, `yes`, or `on`.
# @env GRAYT_REPO_REFRESH_LATENCY Seconds passed to `fswatch --latency`; defaults to `0.5`.
# @env GRAYT_HIDE_INFO Stops any active watcher when the Git info segment is hidden.
# @env GRAYT_HIDE_STATUS Stops any active watcher when Git status is hidden.

[[ -o interactive ]] || return 0 2> /dev/null || exit 0

autoload -Uz add-zsh-hook

if (( ! ${+__grayt_repo_refresh_events_fd} )); then
  typeset -gi __grayt_repo_refresh_events_fd=-1
  typeset -gi __grayt_repo_refresh_pid=-1
  typeset -g  __grayt_repo_refresh_root=
fi

##
# @description Run `git` without taking optional locks.
#
# The prompt may call Git while another terminal or tool is updating repository
# state. `GIT_OPTIONAL_LOCKS=0` tells Git to avoid optional index refresh locks,
# which helps keep prompt redraws from competing with foreground Git commands.
#
# @arg $@ Arguments passed directly to `git`.
# @stdout Whatever the invoked `git` command writes to stdout.
# @stderr Whatever the invoked `git` command writes to stderr.
# @exitcode 0 The invoked `git` command succeeded.
# @exitcode non-zero The invoked `git` command failed.
function __grayt_repo_refresh_git() {
  GIT_OPTIONAL_LOCKS=0 command git "$@"
}

##
# @description Check whether repo refresh is enabled.
#
# This defaults off so the theme remains lightweight unless the user opts in
# from their zsh startup file.
#
# @env GRAYT_REPO_REFRESH Input toggle. Truthy values are `1`, `true`, `yes`, and `on`, case-insensitive for the named values used here.
# @noargs
# @exitcode 0 Repo refresh is enabled.
# @exitcode 1 Repo refresh is disabled.
function __grayt_repo_refresh_enabled() {
  case "${GRAYT_REPO_REFRESH:-0}" in
    1|true|TRUE|yes|YES|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

##
# @description Print a sanitized fswatch latency value.
#
# `fswatch --latency` expects a number of seconds. This accepts whole numbers,
# decimal numbers like `0.5`, and leading-dot decimals like `.25`; everything
# else falls back to the default.
#
# @env GRAYT_REPO_REFRESH_LATENCY Requested watcher latency in seconds.
# @noargs
# @stdout A numeric latency value suitable for `fswatch --latency`.
# @exitcode 0 Always succeeds.
function __grayt_repo_refresh_latency() {
  emulate -L zsh
  setopt localoptions extendedglob

  local latency="${GRAYT_REPO_REFRESH_LATENCY:-0.5}"

  if [[ "$latency" != <->(|.<->) && "$latency" != .<-> ]]; then
    latency=0.5
  fi

  print -r -- "$latency"
}

##
# @description Escape a string for use in an extended regular expression.
#
# `fswatch --extended -e` receives regex filters. Git paths can contain
# characters that are meaningful to a regex engine, so this function quotes
# those characters before building filter patterns.
#
# @arg $1 String to escape.
# @set REPLY Escaped string.
# @stdout Nothing
# @exitcode 0 Always succeeds.
function __grayt_repo_refresh_quote_ere() {
  local value="$1"

  value=${value//\\/\\\\}
  value=${value//\[/\\[}
  value=${value//\]/\\]}
  value=${value//./\\.}
  value=${value//\^/\\^}
  value=${value//\$/\\$}
  value=${value//\*/\\*}
  value=${value//+/\\+}
  value=${value//\?/\\?}
  value=${value//\(/\\(}
  value=${value//\)/\\)}
  value=${value//\{/\\{}
  value=${value//\}/\\}}
  value=${value//|/\\|}

  REPLY="$value"
}

##
# @description Stop the active watcher and clear tracked state.
#
# This removes the `zle -F` file-descriptor handler, closes the FIFO read
# descriptor, kills the background `fswatch` process, waits for it to exit, and
# forgets the repository root. It is safe to call when no watcher is running.
#
# @set __grayt_repo_refresh_events_fd Reset to `-1`.
# @set __grayt_repo_refresh_pid Reset to `-1`.
# @set __grayt_repo_refresh_root Reset to empty.
# @noargs
# @stdout Nothing
# @exitcode 0 Always succeeds.
function __grayt_repo_refresh_shutdown() {
  emulate -L zsh

  if (( __grayt_repo_refresh_events_fd >= 0 )); then
    zle -F "$__grayt_repo_refresh_events_fd" 2> /dev/null
    exec {__grayt_repo_refresh_events_fd}<&-
    __grayt_repo_refresh_events_fd=-1
  fi

  if (( __grayt_repo_refresh_pid > 0 )); then
    kill "$__grayt_repo_refresh_pid" 2> /dev/null
    wait "$__grayt_repo_refresh_pid" 2> /dev/null
    __grayt_repo_refresh_pid=-1
  fi

  __grayt_repo_refresh_root=
}

##
# @description Handle a repository change notification from zle.
#
# zsh calls this through `zle -F` when the watcher FIFO becomes readable. The
# function reads one event, drains any additional batched events already waiting,
# and asks zsh to redraw the current prompt. If the descriptor reports an error
# or EOF, the watcher is shut down.
#
# @arg $1 File descriptor registered with `zle -F`.
# @arg $2 Optional zle error marker.
# @stdout Nothing
# @exitcode 0 Always succeeds.
function __grayt_repo_refresh_on_event() {
  emulate -L zsh

  local fd="$1"
  local error="${2-}"
  local REPLY

  if [[ -n "$error" ]] || ! IFS= read -r -u "$fd"; then
    __grayt_repo_refresh_shutdown
    return 0
  fi

  while IFS= read -r -t 0 -u "$fd"; do
    :
  done

  zle .reset-prompt 2> /dev/null
}

##
# @description Remove temporary FIFO resources.
#
# The watcher uses a temporary directory containing one FIFO. After the parent
# shell opens the FIFO, the filesystem entries can be removed while the open
# descriptor keeps working.
#
# @arg $1 FIFO path to remove.
# @arg $2 Temporary directory path to remove.
# @stdout Nothing
# @exitcode 0 Always succeeds.
function __grayt_repo_refresh_cleanup_fifo() {
  command rm -f -- "$1" 2> /dev/null
  command rmdir -- "$2" 2> /dev/null
}

##
# @description Start watching a Git repository.
#
# This builds fswatch exclude filters for noisy Git internals, creates a FIFO,
# starts `fswatch` in the background, opens the FIFO for zsh, and registers
# `__grayt_repo_refresh_on_event` with `zle -F`.
#
# @arg $1 Absolute worktree root.
# @arg $2 Absolute Git directory for the current worktree.
# @arg $3 Absolute common Git directory.
# @arg $@ Paths for fswatch to observe.
# @env GRAYT_REPO_REFRESH_LATENCY Used through `__grayt_repo_refresh_latency`.
# @set __grayt_repo_refresh_events_fd FIFO read descriptor watched by zle.
# @set __grayt_repo_refresh_pid PID of the background fswatch process.
# @set __grayt_repo_refresh_root Repository root associated with the watcher.
# @stdout Nothing
# @exitcode 0 Watcher started and zle handler registered.
# @exitcode 1 Watcher setup failed.
function __grayt_repo_refresh_start() {
  emulate -L zsh
  setopt localoptions nobgnice

  local root="$1"
  local git_dir="$2"
  local common_dir="$3"
  shift 3

  local -a paths=("$@")
  local -a filters
  local dir tmpdir fifo_dir events_fifo events_fd latency

  for dir in "$git_dir" ${${common_dir:#$git_dir}:+"$common_dir"}; do
    __grayt_repo_refresh_quote_ere "$dir"
    filters+=(
      -e "^${REPLY}/objects(/.*)?$"
      -e "^${REPLY}/logs(/.*)?$"
      -e "^${REPLY}/fsmonitor--daemon(/.*)?$"
      -e "^${REPLY}/fsmonitor--daemon\\.ipc$"
      -e "^${REPLY}/.*\\.lock$"
      -e "^${REPLY}/COMMIT_EDITMSG$"
    )
  done

  tmpdir="${TMPDIR:-/tmp}"
  fifo_dir=$(command mktemp -d "${tmpdir%/}/grayt-repo-refresh.XXXXXX") || return 1
  events_fifo="$fifo_dir/events"

  command mkfifo "$events_fifo" || {
    __grayt_repo_refresh_cleanup_fifo "$events_fifo" "$fifo_dir"
    return 1
  }

  __grayt_repo_refresh_quote_ere "${fifo_dir:A}"
  filters+=(-e "^${REPLY}(/.*)?$")

  latency=$(__grayt_repo_refresh_latency)

  command fswatch --recursive --one-per-batch \
    --latency "$latency" \
    --monitor-property darwin.eventStream.noDefer=true \
    --extended --allow-overflow \
    "${filters[@]}" -- "${paths[@]}" > "$events_fifo" 2> /dev/null &!

  __grayt_repo_refresh_pid=$!

  exec {events_fd}< "$events_fifo" || {
    kill "$__grayt_repo_refresh_pid" 2> /dev/null
    wait "$__grayt_repo_refresh_pid" 2> /dev/null
    __grayt_repo_refresh_pid=-1
    __grayt_repo_refresh_cleanup_fifo "$events_fifo" "$fifo_dir"
    return 1
  }

  __grayt_repo_refresh_cleanup_fifo "$events_fifo" "$fifo_dir"

  __grayt_repo_refresh_root="$root"
  __grayt_repo_refresh_events_fd="$events_fd"

  if ! zle -F "$events_fd" __grayt_repo_refresh_on_event; then
    __grayt_repo_refresh_shutdown
    return 1
  fi
}

##
# @description Start, keep, or stop the watcher for the current directory.
#
# This is the `precmd` hook. It runs before each prompt is displayed, checks the
# user toggle and required commands, asks Git for repository paths, and starts a
# new watcher only when the shell enters a different repository. Moving around
# inside the same repository leaves the existing watcher alone.
#
# @env GRAYT_REPO_REFRESH Enables or disables the feature.
# @env GRAYT_HIDE_INFO Disables watching when Git info is hidden.
# @env GRAYT_HIDE_STATUS Disables watching when Git status is hidden.
# @set __grayt_repo_refresh_events_fd May be set or reset via start/shutdown.
# @set __grayt_repo_refresh_pid May be set or reset via start/shutdown.
# @set __grayt_repo_refresh_root May be set or reset via start/shutdown.
# @noargs
# @stdout Nothing
# @exitcode 0 Always succeeds; watcher startup failures fall back silently.
function __grayt_repo_refresh_check_pwd() {
  emulate -L zsh

  if ! __grayt_repo_refresh_enabled ||
      [[ "${GRAYT_HIDE_INFO:-}" == 1 || "${GRAYT_HIDE_STATUS:-}" == 1 ]]; then
    __grayt_repo_refresh_shutdown
    return 0
  fi

  if ! zmodload zsh/system || ! whence -p fswatch > /dev/null 2>&1; then
    __grayt_repo_refresh_shutdown
    return 0
  fi

  local -a git_dirs paths

  git_dirs=("${(@f)$(
    __grayt_repo_refresh_git rev-parse \
      --show-toplevel \
      --git-dir \
      --git-common-dir \
      2> /dev/null
  )}") || git_dirs=()

  if (( ${#git_dirs} != 3 )); then
    __grayt_repo_refresh_shutdown
    return 0
  fi

  local root="${git_dirs[1]:A}"
  local git_dir="${git_dirs[2]:A}"
  local common_dir="${git_dirs[3]:A}"

  [[ "$root" == "$__grayt_repo_refresh_root" ]] && return 0

  __grayt_repo_refresh_shutdown

  paths=("$root")

  [[ "$git_dir" != "$root" && "$git_dir" != "$root"/* ]] &&
    paths+=("$git_dir")

  [[ "$common_dir" != "$root" && "$common_dir" != "$root"/* && "$common_dir" != "$git_dir" ]] &&
    paths+=("$common_dir")

  __grayt_repo_refresh_start "$root" "$git_dir" "$common_dir" "${paths[@]}" || return 0
}

__grayt_repo_refresh_shutdown

add-zsh-hook -d precmd __grayt_repo_refresh_check_pwd
add-zsh-hook -d zshexit __grayt_repo_refresh_shutdown

add-zsh-hook precmd __grayt_repo_refresh_check_pwd
add-zsh-hook zshexit __grayt_repo_refresh_shutdown
