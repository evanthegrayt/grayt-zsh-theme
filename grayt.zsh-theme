# vi: set ft=zsh :
# erg.zsh-theme
#       I made my own theme. It's a very modified version of dstufft.zsh-theme
#       If you screw anything up, you can probably compare this file to that one
#       to see what got messed up.


PROMPT=$'%{$fg_bold[blue]%}╭─(%{$fg_bold[grey]%}%n%{$fg_bold[blue]%}@%{$fg_bold[grey]%}%m%{$fg_bold[blue]%}|%{$fg_bold[grey]%}zsh%{$fg_bold[blue]%}%{$(git_prompt_info)%}) %{$fg_bold[grey]%}%U${(%):-%~}%u%{$fg_bold[blue]%}\
╰─(%{$fg_bold[grey]%}%T%{$fg_bold[blue]%})=>%{$reset_color%} '
ZSH_THEME_GIT_PROMPT_PREFIX="|%{$fg_bold[grey]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg_bold[blue]%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg_bold[red]%}✗"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg_bold[grey]‽%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg_bold[green]✓%}"

RPROMPT="%(?..%{$fg[red]%}%? ↵%{$reset_color%})"

