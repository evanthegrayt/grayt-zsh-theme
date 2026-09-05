# grayt.zsh-theme; the name says it all

autoload -U colors && colors
setopt prompt_subst

GRAYT_PROMPT_COLOR=${GRAYT_PROMPT_COLOR:-'blue'}
GRAYT_PROMPT_TEXT_COLOR=${GRAYT_PROMPT_TEXT_COLOR:-'grey'}

__grayt_theme_dir=${${(%):-%x}:A:h}
if [[ -r "$__grayt_theme_dir/grayt-repo-refresh.zsh" ]]; then
  source "$__grayt_theme_dir/grayt-repo-refresh.zsh"
fi
unset __grayt_theme_dir

function __grayt_git() {
  GIT_OPTIONAL_LOCKS=0 command git "$@"
}

function __grayt_git_current_ref() {
  local ref

  ref=$(__grayt_git symbolic-ref --short HEAD 2> /dev/null) \
    || ref=$(__grayt_git describe --tags --exact-match HEAD 2> /dev/null) \
    || ref=$(__grayt_git rev-parse --short HEAD 2> /dev/null) \
    || return 0

  echo "$ref"
}

function __grayt_git_truncate_ref() {
  local ref max_length regex prefix_length suffix_length suffix_start name_end

  ref="$1"
  max_length="${GRAYT_MAX_BRANCH_LENGTH:-20}"
  [[ "$max_length" == <-> ]] || max_length=20

  if (( ${#ref} > max_length )); then
    regex="${GRAYT_PREFIX_REGEX:-}"
    if [[ -n "$regex" ]]; then
      ref=$(command sed "s/${regex}//1" <<< "$ref")
    fi

    prefix_length="${GRAYT_PREFIX_LENGTH:-0}"
    [[ "$prefix_length" == <-> ]] || prefix_length=0
    if (( prefix_length > 0 )); then
      ref="${ref[prefix_length + 1,-1]}"
    fi
  fi

  if (( ${#ref} > max_length )); then
    suffix_length="${GRAYT_SUFFIX_LENGTH:-0}"
    [[ "$suffix_length" == <-> ]] || suffix_length=0
    name_end=$(( max_length - suffix_length - 3 ))

    if (( name_end <= 0 )); then
      ref="${ref[1,max_length]}"
    else
      suffix_start=$(( ${#ref} - suffix_length + 1 ))
      ref="${ref[1,name_end]}...${ref[suffix_start,-1]}"
    fi
  fi

  echo "$ref"
}

function grayt_parse_git_dirty() {
  local status_text
  local -a flags

  if [[ "${GRAYT_HIDE_DIRTY:-}" == 1 ]]; then
    echo "%{$fg_bold[green]%}✓"
    return 0
  fi

  flags=(--porcelain)
  [[ "${DISABLE_UNTRACKED_FILES_DIRTY:-}" == true ]] && flags+=(--untracked-files=no)

  case "${GIT_STATUS_IGNORE_SUBMODULES:-}" in
    git) ;;
    *) flags+=("--ignore-submodules=${GIT_STATUS_IGNORE_SUBMODULES:-dirty}") ;;
  esac

  status_text=$(__grayt_git status "${flags[@]}" 2> /dev/null)

  if [[ -n "$status_text" ]]; then
    echo "%{$fg_bold[red]%}✗"
  else
    echo "%{$fg_bold[green]%}✓"
  fi
}

function grayt_git_prompt_info() {
  local ref

  if ! __grayt_git rev-parse --git-dir &> /dev/null \
      || [[ "${GRAYT_HIDE_INFO:-}" == 1 ]] \
      || [[ "${GRAYT_HIDE_STATUS:-}" == 1 ]]; then
    return 0
  fi

  ref=$(__grayt_git_current_ref) || return 0
  ref=$(__grayt_git_truncate_ref "$ref")

  echo "|%{$fg_bold[$GRAYT_PROMPT_TEXT_COLOR]%}${ref//\%/%%}$(grayt_parse_git_dirty)%{$fg_bold[$GRAYT_PROMPT_COLOR]%}"
}

function grayt_pwd_info() {
  local max_length

  if [[ "${GRAYT_DISABLE_PWD_TRUNCATION:-}" == 1 ]]; then
    echo "${(%):-%~}"
    return 0
  fi

  max_length="${GRAYT_MAX_PWD_LENGTH:-35}"
  [[ "$max_length" == <-> ]] || max_length=35

  echo "${(%):-%${max_length}<...<%~%<<}"
}

PROMPT=$'%{$fg_bold[$GRAYT_PROMPT_COLOR]%}╭─(%{$fg_bold[$GRAYT_PROMPT_TEXT_COLOR]%}%n%{$fg_bold[$GRAYT_PROMPT_COLOR]%}@%{$fg_bold[$GRAYT_PROMPT_TEXT_COLOR]%}%m%{$fg_bold[$GRAYT_PROMPT_COLOR]%}%{$(grayt_git_prompt_info)%}) %{$fg_bold[$GRAYT_PROMPT_TEXT_COLOR]%}%U%{$(grayt_pwd_info)%}%u%{$fg_bold[$GRAYT_PROMPT_COLOR]%}\
╰─(%{$fg_bold[$GRAYT_PROMPT_TEXT_COLOR]%}%T%{$fg_bold[$GRAYT_PROMPT_COLOR]%})=>%{$reset_color%} '

RPROMPT="%(?..%{$fg[red]%}%? ↵%{$reset_color%})"

# vi: set ft=zsh :
