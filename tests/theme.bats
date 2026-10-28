#!/usr/bin/env bats

setup() {
  export THEME="$BATS_TEST_DIRNAME/../grayt.zsh-theme"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  # Keep user Git configuration and shell customization out of fixtures.
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE
  export GIT_AUTHOR_NAME='Theme Tests' GIT_AUTHOR_EMAIL='tests@example.invalid'
  export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
  export LC_ALL=C
  cd "$BATS_TEST_TMPDIR"
}

# Bats runs in Bash; all theme behavior must execute in a fresh zsh.
# Clear inherited customization before sourcing, allowing each test to set it explicitly.
theme() {
  run zsh -f -c '
    for setting in ${(k)parameters}; do
      [[ $setting == GRAYT_* ]] && unset "$setting"
    done
    unset DISABLE_UNTRACKED_FILES_DIRTY GIT_STATUS_IGNORE_SUBMODULES
    source "$THEME"
    eval "$1"
  ' theme-test "$1"
  [ "$status" -eq 0 ]
}

repository() {
  git init -q -b main repo
  cd repo
  printf 'original\n' > tracked
  git add tracked
  git -c commit.gpgsign=false commit -qm 'Initial commit'
}

@test "short and boundary-length branch names are unchanged" {
  theme '__grayt_git_truncate_ref short; __grayt_git_truncate_ref abcdefghijklmnopqrst'
  [ "$output" = $'short\nabcdefghijklmnopqrst' ]
}

@test "long branches use the default length and ellipsis" {
  theme '__grayt_git_truncate_ref abcdefghijklmnopqrstuvwxyz'
  [ "$output" = 'abcdefghijklmnopq...' ]
}

@test "custom length preserves the requested suffix" {
  theme 'GRAYT_MAX_BRANCH_LENGTH=12; GRAYT_SUFFIX_LENGTH=4; __grayt_git_truncate_ref abcdefghijklmnopqrstuvwxyz'
  [ "$output" = 'abcde...wxyz' ]
}

@test "regex and fixed prefixes are removed from long names" {
  theme 'GRAYT_MAX_BRANCH_LENGTH=10; GRAYT_PREFIX_REGEX="^[^-]*-"; GRAYT_PREFIX_LENGTH=2; __grayt_git_truncate_ref ticket-XXshort'
  [ "$output" = short ]
}

@test "prefix removal does not alter names already within the limit" {
  theme 'GRAYT_PREFIX_REGEX="^[^-]*-"; GRAYT_PREFIX_LENGTH=2; __grayt_git_truncate_ref XX-short'
  [ "$output" = XX-short ]
}

@test "invalid numeric branch settings fall back to defaults" {
  theme 'GRAYT_MAX_BRANCH_LENGTH=invalid; GRAYT_PREFIX_LENGTH=-1; GRAYT_SUFFIX_LENGTH=invalid; __grayt_git_truncate_ref abcdefghijklmnopqrstuvwxyz'
  [ "$output" = 'abcdefghijklmnopq...' ]
}

@test "small limits and oversized suffixes fall back to a plain slice" {
  theme 'GRAYT_MAX_BRANCH_LENGTH=3; __grayt_git_truncate_ref abcdef; GRAYT_MAX_BRANCH_LENGTH=5; GRAYT_SUFFIX_LENGTH=9; __grayt_git_truncate_ref abcdefghijk'
  [ "$output" = $'abc\nabcde' ]
}

@test "outside a repository Git information is empty" {
  theme 'grayt_git_prompt_info'
  [ -z "$output" ]
}

@test "a branch is displayed even before the first commit" {
  git init -q -b main repo
  cd repo
  theme '__grayt_git_current_ref'
  [ "$output" = main ]
}

@test "current reference follows branch switches" {
  repository
  git checkout -qb feature
  theme '__grayt_git_current_ref'
  [ "$output" = feature ]
}

@test "detached HEAD displays an exact tag" {
  repository
  git -c tag.gpgsign=false tag release-1
  git checkout -q --detach
  theme '__grayt_git_current_ref'
  [ "$output" = release-1 ]
}

@test "untagged detached HEAD displays the abbreviated commit" {
  repository
  expected=$(git rev-parse --short HEAD)
  git checkout -q --detach
  theme '__grayt_git_current_ref'
  [ "$output" = "$expected" ]
}

@test "clean repository displays a green check" {
  repository
  theme '[[ $(grayt_parse_git_dirty) == "%{$fg_bold[green]%}✓" ]]'
}

@test "unstaged changes display a red cross" {
  repository
  printf 'changed\n' >> tracked
  theme '[[ $(grayt_parse_git_dirty) == "%{$fg_bold[red]%}✗" ]]'
}

@test "staged changes display a red cross" {
  repository
  printf 'changed\n' >> tracked
  git add tracked
  theme '[[ $(grayt_parse_git_dirty) == "%{$fg_bold[red]%}✗" ]]'
}

@test "untracked files are dirty unless explicitly ignored" {
  repository
  touch untracked
  theme '[[ $(grayt_parse_git_dirty) == "%{$fg_bold[red]%}✗" ]] || exit 1; DISABLE_UNTRACKED_FILES_DIRTY=true; [[ $(grayt_parse_git_dirty) == "%{$fg_bold[green]%}✓" ]]'
}

@test "ignoring untracked files still detects tracked changes" {
  repository
  printf 'changed\n' >> tracked
  theme 'DISABLE_UNTRACKED_FILES_DIRTY=true; [[ $(grayt_parse_git_dirty) == "%{$fg_bold[red]%}✗" ]]'
}

@test "hide dirty returns a check without querying Git" {
  theme 'GRAYT_HIDE_DIRTY=1; __grayt_git() { print -u2 unexpected-git-call; return 1; }; grayt_parse_git_dirty'
  [[ "$output" == *✓ ]]
  [[ "$output" != *unexpected-git-call* ]]
}

@test "each Git visibility setting hides the segment" {
  repository
  theme 'GRAYT_HIDE_INFO=1; grayt_git_prompt_info; unset GRAYT_HIDE_INFO; GRAYT_HIDE_STATUS=1; grayt_git_prompt_info'
  [ -z "$output" ]
}

@test "Git segment includes branch and clean indicator" {
  repository
  theme '[[ $(grayt_git_prompt_info) == "|%{$fg_bold[$GRAYT_PROMPT_TEXT_COLOR]%}main%{$fg_bold[green]%}✓%{$fg_bold[$GRAYT_PROMPT_COLOR]%}" ]]'
}

@test "percent signs in branch names are escaped for prompt expansion" {
  repository
  git checkout -qb 'feature%n'
  theme '[[ $(grayt_git_prompt_info) == *"feature%%n"* ]]'
}

@test "home directory is abbreviated" {
  cd "$HOME"
  theme 'grayt_pwd_info'
  [ "$output" = '~' ]
}

@test "directory display truncates to the default limit" {
  mkdir -p "$HOME/abcdefghijklmnopqrstuvwxyz/abcdefghijklmnopqrstuvwxyz"
  cd "$HOME/abcdefghijklmnopqrstuvwxyz/abcdefghijklmnopqrstuvwxyz"
  theme 'grayt_pwd_info'
  [ "$output" = '...vwxyz/abcdefghijklmnopqrstuvwxyz' ]
}

@test "directory display supports a custom limit" {
  mkdir -p "$HOME/abcdefghijklmnopqrstuvwxyz"
  cd "$HOME/abcdefghijklmnopqrstuvwxyz"
  theme 'GRAYT_MAX_PWD_LENGTH=10; grayt_pwd_info'
  [ "$output" = '...tuvwxyz' ]
}

@test "invalid directory limit falls back to the default" {
  mkdir -p "$HOME/abcdefghijklmnopqrstuvwxyz/abcdefghijklmnopqrstuvwxyz"
  cd "$HOME/abcdefghijklmnopqrstuvwxyz/abcdefghijklmnopqrstuvwxyz"
  theme 'GRAYT_MAX_PWD_LENGTH=invalid; grayt_pwd_info'
  [ "$output" = '...vwxyz/abcdefghijklmnopqrstuvwxyz' ]
}

@test "directory truncation can be disabled" {
  mkdir -p "$HOME/abcdefghijklmnopqrstuvwxyz/abcdefghijklmnopqrstuvwxyz"
  cd "$HOME/abcdefghijklmnopqrstuvwxyz/abcdefghijklmnopqrstuvwxyz"
  theme 'GRAYT_DISABLE_PWD_TRUNCATION=1; grayt_pwd_info'
  [ "$output" = '~/abcdefghijklmnopqrstuvwxyz/abcdefghijklmnopqrstuvwxyz' ]
}
