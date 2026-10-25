"""Search configured shortcuts or run Niri actions against the original window."""

import argparse
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys


# Launching apps already belongs to Amane. Numbered workspace names are managed
# by Nix; diagnostic/urgency flags are intended for compositor or client testing.
EXCLUDED = {
    "help", "spawn", "spawn-sh", "do-screen-transition", "toggle-debug-tint",
    "debug-toggle-opaque-regions", "debug-toggle-damage", "toggle-window-urgent",
    "set-window-urgent", "unset-window-urgent", "set-workspace-name",
    "unset-workspace-name",
}
PARAMETER_ACTIONS = {
    "focus-window", "focus-column", "focus-window-in-column",
    "move-column-to-index", "move-workspace-to-index", "focus-monitor",
    "move-window-to-monitor", "move-column-to-monitor", "move-workspace-to-monitor",
    "focus-workspace", "move-window-to-workspace", "move-column-to-workspace",
    "set-column-width", "set-window-width", "set-window-height",
    "set-column-display", "switch-layout", "move-floating-window", "stop-cast",
}


def read(*args):
    return subprocess.check_output(["niri", "msg", *args], text=True)


def data(command):
    return json.loads(read("--json", command))


def ipc_action(name, parameters):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
        connection.settimeout(5)
        connection.connect(os.environ["NIRI_SOCKET"])
        connection.sendall((json.dumps({"Action": {name: parameters}}) + "\n").encode())
        with connection.makefile("r") as reply:
            result = json.loads(reply.readline())
        if "Err" in result:
            raise ValueError(result["Err"])


def catalog():
    lines = read("action", "--help").splitlines()
    return [(line.strip(), lines[i + 1].strip())
            for i, line in enumerate(lines[:-1])
            if re.fullmatch(r"  [a-z][a-z-]+", line) and line.strip() not in EXCLUDED]


def clean(value):
    return " ".join(str(value or "").split())


def choose(rows, prompt):
    if not rows:
        raise ValueError("There are no available targets.")
    result = subprocess.run(
        ["fzf", "--layout=reverse", "--border", "--no-sort", "--delimiter=\t",
         "--with-nth=2..", "--prompt", prompt + " > ",
         "--header", "Type to search · Enter to choose · Esc to cancel"],
        input="\n".join(f"{key}\t{clean(label)}" for key, label in rows),
        text=True, stdout=subprocess.PIPE,
    )
    if result.returncode != 0:
        raise KeyboardInterrupt
    return result.stdout.rstrip("\n").split("\t", 1)[0]


def ask(prompt, pattern):
    value = input(prompt + " (blank cancels): ").strip()
    if not value:
        raise KeyboardInterrupt
    if not re.fullmatch(pattern, value):
        raise ValueError("That value is not valid.")
    return value


def action_args(action):
    if action == "focus-window":
        return ["--id", choose(
            [(str(w["id"]), f'{w["app_id"]}: {w["title"]}') for w in data("windows")
             if w["app_id"] != "niri-tools"], "Window")]
    if action in {"focus-monitor", "move-window-to-monitor", "move-column-to-monitor", "move-workspace-to-monitor"}:
        return [choose([(name, name) for name in data("outputs")], "Monitor")]
    if action in {"focus-workspace", "move-window-to-workspace", "move-column-to-workspace"}:
        # IPC IDs avoid confusing numeric workspace names with their current index.
        return [choose([(str(w["id"]),
                         f'{w["name"] or w["idx"]} · {w["output"]}')
                        for w in data("workspaces")], "Workspace")]
    if action in {"focus-column", "focus-window-in-column", "move-column-to-index", "move-workspace-to-index"}:
        return [ask("Position (starting from 1)", r"[1-9][0-9]*")]
    if action in {"set-column-width", "set-window-width", "set-window-height"}:
        # -- stops a negative size adjustment being interpreted as a CLI option.
        return ["--", ask("Size: pixels, percentage, or adjustment (e.g. 800, 50%, -10%)",
                          r"[+-]?[0-9]+(?:\.[0-9]+)?%?")]
    if action == "set-column-display":
        return [choose([("normal", "Stacked windows"), ("tabbed", "Tabbed windows")], "Column layout")]
    if action == "switch-layout":
        return [choose([("next", "Next keyboard layout"), ("prev", "Previous keyboard layout")], "Keyboard layout")]
    if action == "move-floating-window":
        x = ask("Horizontal position or adjustment (e.g. 100, +40, -40)", r"[+-]?[0-9]+")
        y = ask("Vertical position or adjustment (e.g. 100, +40, -40)", r"[+-]?[0-9]+")
        return [f"--x={x}", f"--y={y}"]
    if action == "stop-cast":
        casts = data("casts")
        sessions = {str(c["session_id"]): f'Sharing session {c["session_id"]} · {clean(c["target"])}'
                    for c in casts}
        return ["--session-id", choose(list(sessions.items()), "Stop screen sharing")]
    return []


def restore_context():
    context = json.loads(os.environ.get("NIRI_TOOL_CONTEXT", "{}"))
    window = context.get("window")
    if window and any(w["id"] == window["id"] for w in data("windows")):
        read("action", "focus-window", "--id", str(window["id"]))
        return
    workspace = context.get("workspace")
    if workspace:
        current = next((w for w in data("workspaces") if w["id"] == workspace["id"]), None)
        if current:
            ipc_action("FocusWorkspace", {"reference": {"Id": current["id"]}})
            return
    raise ValueError("The original window or workspace is no longer available.")


def shortcut_rows():
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    config = (config_home / "niri/config.kdl").read_text()
    rows = []
    for line in config.splitlines():
        match = re.match(r"\s*(\S+)\s+([^{}]*?)\{\s*(.*?)\s*;\s*\}", line)
        if not match or "+" not in match[1] and match[1] != "Print" and not match[1].startswith("XF86"):
            continue
        key, options, action = match.groups()
        title = re.search(r'hotkey-overlay-title="([^"]+)"', options)
        if title:
            label = title[1]
        elif action.startswith("spawn "):
            # Strip store hashes so the reference shows the executable and args.
            label = re.sub(r'/nix/store/[^/]+/bin/', '', action.removeprefix("spawn "))
        else:
            verb, _, arguments = action.partition(" ")
            label = verb.replace("-", " ") + " " + arguments.replace('"', '')
        rows.append(f"{key.replace('Mod+', 'Super+'):<34} {label}")
    rows.extend(["Super + left mouse drag            Move window",
                 "Super + right mouse drag           Resize window"])
    return rows


def launch(mode, action=None):
    context = {"window": data("focused-window"),
               "workspace": next((w for w in data("workspaces") if w["is_focused"]), None)}
    os.environ["NIRI_TOOL_CONTEXT"] = json.dumps(context)
    args = ["foot", "--app-id=niri-tools", "--title=Niri " + mode,
            "--", sys.executable, __file__, "--inside", mode]
    if action:
        args.extend(["--action", action])
    os.execvp(args[0], args)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=["shortcuts", "actions"])
    parser.add_argument("--inside", action="store_true")
    parser.add_argument("--action")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()
    if args.list:
        if args.mode == "shortcuts":
            print("\n".join(shortcut_rows()))
        else:
            print("\n".join(f"{key}\t{label}" for key, label in catalog()))
        return
    if not args.inside:
        launch(args.mode, args.action)
    if args.mode == "shortcuts":
        subprocess.run(["fzf", "--layout=reverse", "--border", "--no-sort",
                        "--prompt=Search shortcuts > ", "--bind=enter:ignore",
                        "--header=Read-only reference · Esc to close"],
                       input="\n".join(shortcut_rows()), text=True, stdout=subprocess.DEVNULL)
        return
    actions = catalog()
    action = args.action or choose(actions, "Niri action")
    if action not in dict(actions):
        raise ValueError("Unknown action.")
    parameters = action_args(action)
    # The menu runs in a terminal; actions must target the window from before it.
    restore_context()
    execute_action(action, parameters)


def execute_action(action, parameters):
    window = json.loads(os.environ.get("NIRI_TOOL_CONTEXT", "{}")).get("window")
    if not window and ("window" in action or "column" in action) and not action.startswith("focus-"):
        raise ValueError("There was no focused window when the menu opened.")
    if action in {"focus-workspace", "move-window-to-workspace", "move-column-to-workspace"}:
        fields = {"reference": {"Id": int(parameters[0])}}
        if action != "focus-workspace":
            fields["focus"] = True
        if action == "move-window-to-workspace":
            fields["window_id"] = window["id"] if window else None
        ipc_action("".join(word.title() for word in action.split("-")), fields)
        return
    # Use explicit IDs when supported, so a concurrent focus change cannot
    # redirect an operation such as closing a window to the menu terminal.
    if window and action != "focus-window":
        help_text = read("action", action, "--help")
        if "--id <ID>" in help_text:
            parameters = ["--id", str(window["id"]), *parameters]
        elif "--window-id <WINDOW_ID>" in help_text:
            parameters = ["--window-id", str(window["id"]), *parameters]
    subprocess.run(["niri", "msg", "action", action, *parameters], check=True)


if __name__ == "__main__":
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        pass
    except (ValueError, subprocess.CalledProcessError, OSError) as error:
        print(f"Could not complete the action: {error}")
        try:
            input("Press Enter to close.")
        except EOFError:
            pass
