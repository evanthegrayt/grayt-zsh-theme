# grayt-zsh-theme
A simple, yet informative, zsh theme

## Installation
Clone the repository, preferably under `$ZSH_CUSTOM/themes`. Then, link the
theme directly in the `$ZSH_CUSTOM/themes` directory.
```sh
git clone https://github.com/evanthegrayt/grayt-zsh-theme.git $ZSH_CUSTOM/themes
ln -s $ZSH_CUSTOM/themes/grayt-zsh-theme/grayt.zsh-theme $ZSH_CUSTOM/themes
```
Once installed, set the theme in your `~/.zshrc` file.
```sh
export ZSH_THEME="grayt"
```
Re-source your `~/.zshrc`
```sh
. ~/.zshrc
```

### Dependencies
If you want the `git` branch to truncate, you'll need to install
[omz-git](https://github.com/tnwinc/omz-git).

## Screenshots
Here's a few examples, including a non-`git` directory, a clean `git` directory,
an un-clean `git` directory, and a non-zero return code. As you can see, if the
`git` branch and `$PWD` will truncate if they cause the line to be too long.
I'm using [iTerm2](https://www.iterm2.com/) on MacOS, with
the [Hack font](https://sourcefoundry.org/hack/).

![](https://user-images.githubusercontent.com/12698076/69295476-0220dd00-0bd1-11ea-9f46-0ba574d09742.jpg)

## Customization
You can change the main prompt color by adding the following line to your
`~/.zshrc`:

```zsh
GRAYT_PROMPT_COLOR=red # This will make the prompt red
```

## Issues and Reporting Bugs
Please [submit an
issue](https://github.com/evanthegrayt/grayt-zsh-theme/issues/new) if you find
bugs.

