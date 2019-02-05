# vi: set ft=zsh :
# grayt.zsh-theme; the name says it all

# NOTE: I use https://github.com/tnwinc/omz-git for truncating the branch
PROMPT=$'%{$fg_bold[blue]%}╭─(%{$fg_bold[grey]%}%n%{$fg_bold[blue]%}@%{$fg_bold[grey]%}%m%{$fg_bold[blue]%}%{$(git_prompt_info)%}) %{$fg_bold[grey]%}%U%{${(%):-%35<...<%~%<<}%}%u%{$fg_bold[blue]%}\
╰─(%{$fg_bold[grey]%}%T%{$fg_bold[blue]%})=>%{$reset_color%} '
ZSH_THEME_GIT_PROMPT_PREFIX="|%{$fg_bold[grey]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg_bold[blue]%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg_bold[red]%}✗"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg_bold[grey]‽%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg_bold[green]✓%}"

RPROMPT="%(?..%{$fg[red]%}%? ↵%{$reset_color%})"

