"""Exercise config deployment and idempotence without changing the real home."""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import tomllib


ROOT = Path(__file__).resolve().parents[1]


def run(*args, env=None):
    result = subprocess.run(
        args, cwd=ROOT, env=env, text=True, capture_output=True, timeout=90
    )
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout + result.stderr


def verify(home):
    config = home / ".config"
    ghostty = home / "Library/Application Support/com.mitchellh.ghostty/config.ghostty"
    assert ghostty.read_text() == "font-size = 14\nbackground = #242424\n"
    herdr = tomllib.loads((config / "herdr/config.toml").read_text())
    assert herdr["onboarding"] is False
    assert herdr["theme"]["name"] == "gruvbox"
    assert herdr["theme"]["auto_switch"] is False
    assert herdr["theme"]["light"] == "gruvbox-light"
    assert herdr["terminal"]["scrollback_lines"] == 1234
    assert json.loads((config / "opencode/tui.json").read_text())["theme"] == "gruvbox"
    assert (config / "opencode/opencode.jsonc").read_text() == "// local settings\n{}\n"
    assert (config / "fish/config.fish").read_text() == "# local Fish config\n"
    assert (config / "nvim/lua/plugins/local.lua").read_text() == "return {}\n"

    for source in (ROOT / "files/nvim").rglob("*"):
        if source.is_file():
            destination = config / "nvim" / source.relative_to(ROOT / "files/nvim")
            assert destination.read_bytes() == source.read_bytes(), destination
    assert (config / "fish/conf.d/terminal.fish").read_bytes() == (
        ROOT / "files/fish/terminal.fish"
    ).read_bytes()
    assert any(
        backup.read_text() == "return -- old configuration\n"
        for backup in (config / "nvim").glob("init.lua.*~")
    ), "The replaced Neovim configuration was not backed up"


def main():
    with tempfile.TemporaryDirectory(prefix="ansible-setup-") as scratch:
        home = Path(scratch)
        fixtures = {
            "Library/Application Support/com.mitchellh.ghostty/config.ghostty":
                "font-size = 14\nbackground = #000000\n",
            ".config/herdr/config.toml":
                'onboarding = true\n\n[theme]\nname = "nord"\nauto_switch = true\n'
                'light = "gruvbox-light"\n\n[terminal]\nscrollback_lines = 1234\n',
            ".config/opencode/opencode.jsonc": "// local settings\n{}\n",
            ".config/fish/config.fish": "# local Fish config\n",
            ".config/nvim/init.lua": "return -- old configuration\n",
            ".config/nvim/lua/plugins/local.lua": "return {}\n",
        }
        for relative, content in fixtures.items():
            target = home / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content)

        command = (
            "ansible-playbook", "console-utils.yml", "--tags", "config",
            "-i", "localhost,", "-e", json.dumps({
                "setup_home": str(home),
                "ansible_python_interpreter": sys.executable,
            }),
        )
        env = {**os.environ, "ANSIBLE_NOCOLOR": "1", "ANSIBLE_STDOUT_CALLBACK": "default"}
        run(*command, env=env)
        verify(home)
        second = run(*command, env=env)
        assert re.search(r"localhost\s+:.*changed=0\s+.*failed=0", second), second
        verify(home)

        # Check a clean installation as well as migration from existing files.
        clean_home = home / "clean"
        clean_home.mkdir()
        run(*command[:-1], json.dumps({
            "setup_home": str(clean_home),
            "ansible_python_interpreter": sys.executable,
        }), env=env)
        clean_herdr = tomllib.loads((clean_home / ".config/herdr/config.toml").read_text())
        assert clean_herdr == {
            "onboarding": False,
            "theme": {"name": "gruvbox", "auto_switch": False},
        }

        run("fish", "--no-config", "--no-execute", str(home / ".config/fish/conf.d/terminal.fish"))
        lua_check = (
            "for _, path in ipairs(vim.fn.glob('files/nvim/**/*.lua', false, true)) do "
            "assert(loadfile(path)) end; print('LUA VERIFIED')"
        )
        output = run("nvim", "--headless", "-u", "NONE", "-i", "NONE", "+lua " + lua_check, "+qa")
        assert "LUA VERIFIED" in output, output
    print("SETUP VERIFIED")


if __name__ == "__main__":
    main()
