# grayt-zsh-theme
A simple, yet informative, zsh theme.

This prompt focuses on:

- Useful context for everyday development without a crowded prompt.
- Simple styling that stays readable instead of becoming decoration.
- Optional repo refreshes, so Git branch and status changes made in another
  terminal or application can appear without pressing Enter.
- A stable two-line layout that keeps the command cursor predictable, even when
  the current directory or git branch name is long.
- A few practical customization options without a pile of configuration.

## Screenshots
This example shows a default zsh environment with no plugins sourcing the
prompt. No configuration has been done; this is what it looks like out of the
box.  You can see a non-git directory, a clean git directory, an unclean git
directory, and a non-zero return code.

The git branch and current directory both truncate when they get long enough to
crowd the prompt. I'm using [iTerm2](https://www.iterm2.com/) on MacOS, with
the [Hack font](https://sourcefoundry.org/hack/).

![](https://github.com/evanthegrayt/grayt-zsh-theme/releases/download/v2.0.0/grayt-theme-screenshot.png)

## Installation
Clone this repository somewhere you keep zsh plugins, then source the theme from
your `~/.zshrc`.

```sh
# Assuming you clone plugins/themes in `~/.zsh`, but clone wherever you want.
git clone https://github.com/evanthegrayt/grayt-zsh-theme.git ~/.zsh/grayt-zsh-theme
```

```zsh
# Put this in ~/.zshrc. If you cloned somewhere different, update the path.
source ~/.zsh/grayt-zsh-theme/grayt.zsh-theme
```

Restart your shell or re-source your `~/.zshrc`.

```zsh
source ~/.zshrc
```

### Package Managers
Use your favorite zsh package manager by pointing it at this repository and
sourcing `grayt.zsh-theme`.

With [zinit](https://github.com/zdharma-continuum/zinit):

```zsh
zinit ice pick"grayt.zsh-theme"
zinit light evanthegrayt/grayt-zsh-theme
```

With [zplug](https://github.com/zplug/zplug):

```zsh
zplug "evanthegrayt/grayt-zsh-theme", as:theme
```

With [antidote](https://github.com/mattmc3/antidote):

```zsh
evanthegrayt/grayt-zsh-theme path:grayt.zsh-theme
```

With [Oh My Zsh](https://ohmyz.sh/):

```sh
git clone https://github.com/evanthegrayt/grayt-zsh-theme.git \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/grayt-zsh-theme"
ln -s \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/grayt-zsh-theme/grayt.zsh-theme" \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/grayt.zsh-theme"
```

```zsh
ZSH_THEME="grayt"
```

### Dependencies
This theme is standalone. It uses zsh's built-in prompt expansion and color
helpers, and it shells out to `git` when the current directory is inside a
repository. No zsh framework or git prompt plugin is required.

## Customization
Set customization variables before sourcing the theme. In the following
examples, what you see is already the default.

Prompt colors use zsh color names:

```zsh
GRAYT_PROMPT_COLOR=blue
GRAYT_PROMPT_TEXT_COLOR=grey
```

The current directory is truncated to 35 characters by default:

```zsh
GRAYT_MAX_PWD_LENGTH=35
GRAYT_DISABLE_PWD_TRUNCATION=0
```

Git branch names are truncated to 20 characters by default. You can change the
length and optionally strip a prefix or keep a suffix:

```zsh
GRAYT_MAX_BRANCH_LENGTH=20
GRAYT_PREFIX_REGEX='^[^-]*-'
GRAYT_PREFIX_LENGTH=0
GRAYT_SUFFIX_LENGTH=8
```

You can also disable parts of the git prompt. Set a value to `1` to enable the
setting:

```zsh
GRAYT_HIDE_INFO=0
GRAYT_HIDE_STATUS=0
GRAYT_HIDE_DIRTY=0
```

### Repo Refresh
By default, the prompt updates when zsh renders a new prompt. If you install
[`fswatch`](https://github.com/emcrisostomo/fswatch), you can opt into idle
refreshes so Git branch and status changes made in another terminal are
reflected without pressing Enter.

```zsh
GRAYT_REPO_REFRESH=1
GRAYT_REPO_REFRESH_LATENCY=0.5
```

`GRAYT_REPO_REFRESH_LATENCY` is passed to `fswatch` as a number of seconds. The
default is `0.5`. To disable repo refreshes again, set `GRAYT_REPO_REFRESH=0` or
leave it unset.

The feature is simple: it starts one watcher for the current Git repository,
requests a prompt redraw when that repository changes, and stops when you leave
the repository or exit the shell. Branch switches use the same watcher as dirty
status changes; no extra process is needed. If `fswatch` is not available, the
theme falls back to the normal prompt behavior.

## Issues and Reporting Bugs
Please [submit an
issue](https://github.com/evanthegrayt/grayt-zsh-theme/issues/new) if you find
bugs.

## Support this project
I love knowing when people find my work useful. Any kind of support is very much
appreciated!

- ⭐️ Like the project? Star [the repository](https://github.com/evanthegrayt/grayt-zsh-theme)!
- ❤️ Love the project? Follow me [on GitHub](https://github.com/evanthegrayt)!
- 💸 *Really* love it? Consider [buying me a tea](https://paypal.me/evanrgray)!
