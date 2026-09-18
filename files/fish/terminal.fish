# Homebrew may not yet be on PATH in a fresh Fish login shell.
if not command -sq brew
    if test -x /opt/homebrew/bin/brew
        /opt/homebrew/bin/brew shellenv fish | source
    else if test -x /usr/local/bin/brew
        /usr/local/bin/brew shellenv fish | source
    end
end

set -gx EDITOR nvim
set -gx VISUAL nvim

if not status is-interactive
    return
end

function ls --wraps eza
    command eza $argv
end

function cat --wraps bat
    command bat $argv
end

function top --wraps htop
    command htop $argv
end

function help --wraps tldr
    command tldr $argv
end

function ping --wraps prettyping
    command prettyping $argv --nolegend
end

if command -sq fzf
    fzf --fish | source
end
