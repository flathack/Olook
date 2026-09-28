"""The parts of an install that live outside the plugin folder.

`omarchy plugin add` clones the repository into the plugins folder and stops
there, which is enough for mail to work. Four things are left that make it
feel installed: the `olook` command on the PATH, the small library that lets
the reading pane render HTML, being the desktop's handler for mailto: links,
and an entry in the app menu. This does all four, from Settings or from
install.sh, and reports what it found either way.

The one step it will not take is editing Hyprland's config: the renderer needs
the plugin's shell launcher first on PATH, so the preload stays in the Omarchy
shell launch chain. That line belongs to the user and is handed back to add.
"""

import hashlib
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path

from . import config

PLUGIN_DIR = Path(__file__).resolve().parents[2]
ENGINE = PLUGIN_DIR / "bin" / "olook"
SHIM_SOURCE = PLUGIN_DIR / "lib" / "argcshim.c"
SHIM = PLUGIN_DIR / "lib" / "argcshim.so"
SHELL_LAUNCHER = PLUGIN_DIR / "bin" / "omarchy-launch-shell"

HOME = Path.home()
BIN_LINK = HOME / ".local" / "bin" / "olook"
APPS_DIR = HOME / ".local" / "share" / "applications"
DESKTOP_NAME = "olook-mailto.desktop"
DESKTOP_FILE = APPS_DIR / DESKTOP_NAME
HYPR_CONFIG = HOME / ".config" / "hypr" / "hyprland.lua"
LAUNCHER_FILE = APPS_DIR / "olook.desktop"
ICON_SOURCE = PLUGIN_DIR / "assets" / "olook.svg"
ICON_FILE = HOME / ".local" / "share" / "icons" / "hicolor" / "scalable" / "apps" / "olook.svg"


def _hypr_text():
    try:
        return HYPR_CONFIG.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def _mailto_default():
    if not shutil.which("xdg-mime"):
        return ""
    try:
        done = subprocess.run(["xdg-mime", "query", "default", "x-scheme-handler/mailto"],
                              capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return ""
    return done.stdout.strip()


def _shell_has_shim():
    """Whether the running Omarchy shell has mapped this shim.

    The shim removes itself from LD_PRELOAD after loading, so children do not
    inherit it. The process mappings, rather than a caller's environment,
    answer whether the shell really loaded the library.
    """
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if (entry / "comm").read_text().strip() != "quickshell":
                continue
            if (entry / "environ").stat().st_uid != os.getuid():
                continue
            shell_dir = str(Path(os.environ.get("OMARCHY_PATH", "/usr/share/omarchy")) / "shell")
            if shell_dir.encode() not in (entry / "cmdline").read_bytes():
                continue
            return str(SHIM) in (entry / "maps").read_text(errors="replace")
        except OSError:
            continue
    return False


def check():
    """Where each part stands, without changing anything."""
    hypr = _hypr_text()
    line = ('hl.env("PATH", ' + json.dumps(str(SHELL_LAUNCHER.parent) + ":")
            + ' .. (os.getenv("OMARCHY_PATH") or "/usr/share/omarchy")'
            + ' .. "/bin:" .. (os.getenv("PATH") or "/usr/local/bin:/usr/bin"))')
    legacy = "argcshim.so" in hypr and "LD_PRELOAD" in hypr
    return {
        "cli": {
            "ok": _bin_is_ours() and BIN_LINK.resolve() == ENGINE.resolve(),
            "path": str(BIN_LINK),
        },
        "renderer": {
            "built": SHIM.exists(),
            "active": _shell_has_shim(),
            "configured": line in hypr and SHELL_LAUNCHER.is_file(),
            "stale": legacy,
            "line": line,
            "launcher": str(SHELL_LAUNCHER),
            "compiler": bool(shutil.which("gcc")),
        },
        "mailto": {
            "ok": _mailto_default() == DESKTOP_NAME
                  and _ours(DESKTOP_FILE, _mailto_entry(), *_legacy_mailto_entries()),
            "current": _mailto_default(),
        },
        "launcher": {
            "ok": _ours(LAUNCHER_FILE, _launcher_entry()) and _ours(ICON_FILE, _icon()),
        },
    }


# ------------------------------------------------------ files outside the plugin
#
# Everything below writes where the user keeps their own things: the PATH,
# the applications folder, the icon theme. So nothing there is overwritten or
# removed unless it is still exactly what Olook put there. What Olook writes
# is recorded by content hash; a file whose hash still matches is Olook's, one
# that was edited or was never Olook's is left alone and reported. A symlink
# is never written through or removed, except the command link, which is
# Olook's only while it points at an Olook engine. Files from installs made
# before the record existed are recognised by being byte for byte what Olook
# writes.

RECORD = config.STATE_DIR / "installed.json"


def _digest(data):
    return hashlib.sha256(data).hexdigest()


def _load_record():
    try:
        found = json.loads(RECORD.read_text(encoding="utf-8"))
        return found if isinstance(found, dict) else {}
    except (OSError, ValueError):
        return {}


def _save_record(record):
    config.ensure_dirs()
    fd, tmp = tempfile.mkstemp(dir=RECORD.parent, prefix=".installed-")
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(record, handle, indent=2, sort_keys=True)
    os.chmod(tmp, 0o600)
    os.replace(tmp, RECORD)


def _ours(path, *known):
    """Whether path is a plain file Olook wrote and nobody has changed."""
    if path.is_symlink() or not path.is_file():
        return False
    try:
        data = path.read_bytes()
    except OSError:
        return False
    recorded = _load_record().get(str(path))
    if recorded and recorded == _digest(data):
        return True
    return any(data == content for content in known if content is not None)


def _occupied(path):
    return path.is_symlink() or path.exists()


def _place(path, data, mode, *legacy):
    """Put data at path, unless something that is not Olook's is there."""
    if _occupied(path) and not _ours(path, data, *legacy):
        return f"left {path} alone: it is not Olook's, or was changed"
    path.parent.mkdir(parents=True, exist_ok=True)
    # A new file renamed over the old one: the rename replaces the directory
    # entry, so even a symlink put there in the meantime is not written
    # through.
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".olook-")
    with os.fdopen(fd, "wb") as handle:
        handle.write(data)
    os.chmod(tmp, mode)
    os.replace(tmp, path)
    record = _load_record()
    record[str(path)] = _digest(data)
    _save_record(record)
    return ""


def _unplace(path, data, *legacy):
    """Remove path, if it is still exactly what Olook put there."""
    if not _occupied(path):
        return ""
    if not _ours(path, data, *legacy):
        return f"left {path} alone: it is not Olook's, or was changed"
    path.unlink()
    record = _load_record()
    record.pop(str(path), None)
    _save_record(record)
    return ""


def _is_engine(target):
    """A link target that is an Olook engine: this one, or an earlier install
    of the plugin under another folder name."""
    target = str(target)
    return target == str(ENGINE) or (
        target.endswith("/bin/olook") and "/.config/omarchy/plugins/" in target)


def _bin_is_ours():
    try:
        return BIN_LINK.is_symlink() and _is_engine(os.readlink(BIN_LINK))
    except OSError:
        return False


def _link_cli():
    if _occupied(BIN_LINK) and not _bin_is_ours():
        return f"left {BIN_LINK} alone: it is not Olook's"
    BIN_LINK.parent.mkdir(parents=True, exist_ok=True)
    tmp = BIN_LINK.parent / f".olook-link-{os.getpid()}"
    if _occupied(tmp):
        tmp.unlink()
    tmp.symlink_to(ENGINE)
    os.replace(tmp, BIN_LINK)
    return ""


def _build_shim():
    if not shutil.which("gcc"):
        return "no compiler: install gcc to render mail as HTML"
    done = subprocess.run(["gcc", "-shared", "-fPIC", "-O2", "-o", str(SHIM),
                           str(SHIM_SOURCE), "-ldl"],
                          capture_output=True, text=True, timeout=120)
    if done.returncode != 0:
        return "could not build the renderer library: " + done.stderr.strip()[:200]
    return ""


def _mailto_entry(exec_path=None):
    return ("[Desktop Entry]\n"
            "Type=Application\n"
            "Name=Olook\n"
            "Comment=Write an email in Olook\n"
            f"Exec={exec_path or ENGINE} mailto %u\n"
            "Icon=mail-message-new\n"
            "Terminal=false\n"
            "NoDisplay=true\n"
            "MimeType=x-scheme-handler/mailto;\n"
            "Categories=Office;Network;Email;\n").encode("utf-8")


# install.sh wrote the handler before Finish setup did, with the PATH link as
# the command.
def _legacy_mailto_entries():
    return (_mailto_entry(BIN_LINK),)


def _launcher_entry():
    # omarchy-shell adds the empty payload a three-word summon needs.
    return ("[Desktop Entry]\n"
            "Type=Application\n"
            "Name=Olook\n"
            "GenericName=Mail\n"
            "Comment=Mail, calendar and contacts\n"
            "Exec=omarchy-shell shell summon ttt.olook\n"
            "Icon=olook\n"
            "Terminal=false\n"
            "StartupNotify=false\n"
            "Categories=Network;Email;\n"
            "Keywords=mail;email;inbox;calendar;contacts;outlook;\n"
            "Actions=compose;\n"
            "\n"
            "[Desktop Action compose]\n"
            "Name=New message\n"
            "Exec=omarchy-shell ttt.olook-window newMessage\n").encode("utf-8")


def _icon():
    try:
        return ICON_SOURCE.read_bytes()
    except OSError:
        return None


def _refresh_desktop_database():
    if shutil.which("update-desktop-database"):
        subprocess.run(["update-desktop-database", str(APPS_DIR)],
                       capture_output=True, timeout=30)


def _register_mailto():
    """The mailto: handler, and the default -- only if the entry is Olook's."""
    trouble = _place(DESKTOP_FILE, _mailto_entry(), 0o644, *_legacy_mailto_entries())
    if trouble:
        return "", trouble
    previous = _mailto_default()
    if shutil.which("xdg-mime") and previous != DESKTOP_NAME:
        subprocess.run(["xdg-mime", "default", DESKTOP_NAME, "x-scheme-handler/mailto"],
                       capture_output=True, timeout=10)
    _refresh_desktop_database()
    return (previous if previous != DESKTOP_NAME else ""), ""


def _register_launcher():
    """Olook in the app menu: the window, and a new message from its actions.

    The menu lists desktop entries, and until this the only one was the
    hidden mailto: handler -- so the app could be opened from the bar, a
    keybinding or a terminal, but not found by name.
    """
    problems = []
    icon = _icon()
    if icon is not None:
        trouble = _place(ICON_FILE, icon, 0o644)
        if trouble:
            problems.append(trouble)
    trouble = _place(LAUNCHER_FILE, _launcher_entry(), 0o644)
    if trouble:
        problems.append(trouble)
    _refresh_desktop_database()
    return problems


def run():
    """Do every step that is ours to do, and report what is left."""
    problems = []
    for trouble in (_link_cli(), _build_shim()):
        if trouble:
            problems.append(trouble)
    replaced, trouble = _register_mailto()
    if trouble:
        problems.append(trouble)
    problems.extend(_register_launcher())
    state = check()
    return {"state": state, "problems": problems, "replacedMailto": replaced}


def remove():
    """Undo what run() put outside the plugin folder -- only what is still
    Olook's. Returns what was left alone, and why."""
    problems = []
    if _occupied(BIN_LINK):
        if _bin_is_ours():
            BIN_LINK.unlink()
        else:
            problems.append(f"left {BIN_LINK} alone: it is not Olook's")
    for path, data, legacy in ((DESKTOP_FILE, _mailto_entry(), _legacy_mailto_entries()),
                               (LAUNCHER_FILE, _launcher_entry(), ()),
                               (ICON_FILE, _icon(), ())):
        trouble = _unplace(path, data, *legacy)
        if trouble:
            problems.append(trouble)
    renderer = check()["renderer"]
    if renderer["stale"]:
        problems.append("remove the old LD_PRELOAD line containing argcshim.so "
                        "from ~/.config/hypr/hyprland.lua")
    if renderer["configured"]:
        problems.append("remove Olook's PATH line from "
                        "~/.config/hypr/hyprland.lua")
    _refresh_desktop_database()
    return problems
