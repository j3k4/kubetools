# System-wide .zshenv file for zsh(1), sourced on all invocations of the shell.
#
# Global order: zshenv, zprofile, zshrc, zlogin

export ZDOTDIR=/root/data


# If $ZDOTDIR is not set and none of .zshenv, .zprofile, .zshrc, .zlogin exist
# in $HOME, read ZSH startup files from $XDG_CONFIG_HOME/zsh/ instead of $HOME. # The point is to promote XDG-based location, but don't break existing setups.
if [[ -z "${ZDOTDIR-}" ]] && _x=("$HOME"/.z{shenv,profile,shrc,login}(N)) && (( ! $#_x ));    then
    ZDOTDIR=${XDG_CONFIG_HOME:-$HOME/.config}/zsh
fi
unset _x
