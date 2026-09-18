# MacBook terminal setup

Reproduce the Fish → Ghostty → herdr → OpenCode / Neovim workspace.

| Component | Setup |
| --- | --- |
| Fish | Login shell, console aliases, fzf bindings, Neovim as `$EDITOR` |
| Ghostty | Default palette with a slightly darker `#242424` background |
| herdr | Gruvbox, automatic theme switching disabled |
| OpenCode | Gruvbox UI theme |
| Neovim | LazyVim with Gruvbox dark (`#282828`), Ruby support, Markdown rendering, outline, and Claude Code integration |

The original CLI tools are still installed, with maintained `eza` replacing `exa`.
Fish aliases are `ls → eza`, `cat → bat`, `top → htop`, `help → tldr`, and
`ping → prettyping --nolegend`. Arguments are forwarded to each tool.

## Install

Start with [Homebrew](https://brew.sh) and the Xcode Command Line Tools installed.
Run as your regular user; only the login-shell tasks need sudo.

```sh
brew install ansible
git clone https://github.com/nemes1s/ansible-setup.git
cd ansible-setup
ansible-galaxy collection install -r requirements.yml
ansible-playbook console-utils.yml --ask-become-pass
```

Homebrew packages use `state: present`, so rerunning the playbook does not upgrade
every tool. It detects Homebrew's prefix for both Apple Silicon and Intel Macs.

After installation:

1. Log out and back in so new terminal sessions and herdr inherit Fish as `$SHELL`.
2. Open Ghostty. For an existing window, reload its config with **⌘⇧,**.
3. Run `herdr`. If its server is already running, use `herdr server reload-config`
   to apply the theme; restart it when ready to pick up a changed login shell.
4. Run `opencode` and connect your provider with `/connect`. Quit and restart an
   existing OpenCode instance to load the UI config.
5. Run `nvim` and let LazyVim install its plugins. `:Lazy restore` restores the
   versions in the supplied `lazy-lock.json`. Internet access is needed on first
   launch; Treesitter and Mason may download additional tools.

The Ruby configuration runs `bundle exec ruby-lsp` and `bundle exec rubocop --lsp`.
Use your project's Ruby environment and install its bundle, including those gems.
The Claude Code Neovim integration requires the Claude Code CLI to be installed
and authenticated separately if you use it.

## Apply only part of the setup

```sh
# Install applications only.
ansible-playbook console-utils.yml --tags packages

# Apply dotfiles and themes only (no sudo or package installation).
ansible-playbook console-utils.yml --tags config

# Set Fish as the login shell after installing it.
ansible-playbook console-utils.yml --tags shell --ask-become-pass

# Install/configure everything without changing the login shell.
ansible-playbook console-utils.yml -e set_fish_login_shell=false

# Preview changes.
ansible-playbook console-utils.yml --check --diff --ask-become-pass
```

## Managed configuration

| Destination | Behavior |
| --- | --- |
| `~/.config/fish/conf.d/terminal.fish` | Managed aliases, Homebrew PATH bootstrap, editor environment and fzf bindings; existing `config.fish` and plugins remain available |
| `~/Library/Application Support/com.mitchellh.ghostty/config.ghostty` | Changes only `background` |
| `~/.config/herdr/config.toml` | Sets onboarding and theme options, preserving other settings |
| `~/.config/opencode/tui.json` | Managed UI config; provider/agent settings and credentials stay separate |
| `~/.config/nvim/` | Copies the files under `files/nvim/`, including plugin lockfile; additional local files are retained |

Changed destination files receive timestamped Ansible backups alongside them.
Edit the repository's managed files to persist customizations across future runs.
If you already have an OpenCode `tui.jsonc`, consolidate your UI settings into the
managed `tui.json` so a second config file cannot override the chosen theme.
Fish loads `config.fish` after `conf.d`, so definitions there can override these
aliases. Neovim's extra local plugin specs can similarly override the defaults.

Customize defaults in `vars/main.yml`, or pass an extra-vars file. For example:

```yaml
ghostty_background: "#242424"
set_fish_login_shell: true
```

`setup_home`, `config_home`, and `ghostty_config_dir` can be overridden for alternate
locations. The default paths reproduce the standard macOS layout used here.
Work-specific Fish environment variables, version-manager setup, credentials,
herdr sessions/logs, and OpenCode conversation state are not stored in this repo.

## Verify

With Ansible, the required collection, Fish, Neovim, and Python 3.11+ installed:

```sh
ansible-playbook console-utils.yml --syntax-check
python3 tests/verify_setup.py
```

The integration check deploys configuration into a temporary home, checks the
resulting theme settings and preserved local settings, then reruns the playbook
to verify zero changes. It also checks Fish/Lua syntax. It does not install
packages or change your login shell. Use `TMPDIR` to select the scratch location.

The LazyVim bootstrap is adapted from [LazyVim/starter](https://github.com/LazyVim/starter);
its Apache 2.0 license is included in `files/nvim/LICENSE`.
