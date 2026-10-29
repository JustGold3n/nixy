"""Run inside dbus-run-session; uses a fake picker and no personal files."""

import argparse
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backend", required=True)
    parser.add_argument("--gdbus", default="gdbus")
    args = parser.parse_args()
    destination = "org.freedesktop.impl.portal.desktop.termfilechooser"
    object_path = "/org/freedesktop/portal/desktop"
    with tempfile.TemporaryDirectory(prefix="portal-security-test-") as temporary:
        root = Path(temporary)
        control = root / "control.json"
        record = root / "record.json"
        picker = root / "picker"
        picker.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\nfrom pathlib import Path\n"
            f"control = json.loads(Path({str(control)!r}).read_text())\n"
            "output = Path(sys.argv[5])\n"
            "info = output.stat()\n"
            f"Path({str(record)!r}).write_text(json.dumps({{"
            "'output': str(output), 'mode': info.st_mode, 'uid': info.st_uid, "
            "'args': sys.argv[1:], 'empty': output.read_bytes() == b''}))\n"
            "output.write_text(''.join(path + '\\n' for path in control['paths']))\n"
            "sys.exit(control.get('exit', 0))\n"
        )
        picker.chmod(0o700)
        config = root / "config"
        config.write_text(
            f"[filechooser]\ncmd={picker}\ndefault_dir={root}\n"
            "open_mode=suggested\nsave_mode=suggested\ncreate_help_file=0\n"
        )
        env = os.environ | {
            "XDG_CONFIG_HOME": str(root / "xdg-config"),
            "XDG_STATE_HOME": str(root / "state"),
        }
        seen = set()
        with (root / "backend.log").open("w+") as log:
            backend = subprocess.Popen(
                [args.backend, "-c", str(config)], cwd=root, env=env, stdout=log, stderr=log
            )
            try:
                for _ in range(100):
                    ready = subprocess.run(
                        [args.gdbus, "introspect", "--session", "--dest", destination,
                         "--object-path", object_path], capture_output=True, timeout=2
                    )
                    if ready.returncode == 0:
                        break
                    if backend.poll() is not None:
                        raise AssertionError("backend exited during startup")
                    time.sleep(0.05)
                else:
                    raise AssertionError("backend did not acquire its D-Bus name")

                def call(name, method="OpenFile", paths=(), options="{}", exit_code=0):
                    control.write_text(json.dumps({"paths": list(map(str, paths)), "exit": exit_code}))
                    result = subprocess.run(
                        [args.gdbus, "call", "--session", "--dest", destination,
                         "--object-path", object_path, "--method",
                         "org.freedesktop.impl.portal.FileChooser." + method,
                         "/org/freedesktop/portal/desktop/request/test/security",
                         "test.security", "", name, options],
                        capture_output=True, text=True, timeout=10,
                    )
                    observed = json.loads(record.read_text())
                    output = Path(observed["output"])
                    assert output.name.startswith("termfilechooser-"), output
                    assert output.name != f"termfilechooser-{os.getuid()}.portal"
                    assert str(output) not in seen, "requests reused a result file"
                    seen.add(str(output))
                    assert observed["empty"], "result file was not initially empty"
                    assert stat.S_IMODE(observed["mode"]) == 0o600, observed
                    assert observed["uid"] == os.getuid(), observed
                    assert not output.exists(), "result file leaked after request"
                    if exit_code:
                        assert result.returncode != 0 or not result.stdout.startswith("(uint32 0,"), result
                    else:
                        assert result.returncode == 0, result.stderr
                        expected = 0 if paths else 1
                        assert result.stdout.startswith(f"(uint32 {expected},"), result.stdout
                        for path in paths:
                            assert path.as_uri() in result.stdout, result.stdout
                    print("PASS:", name, flush=True)
                    return observed

                first = root / "žluťoučký file's name.txt"
                second = root / "second.txt"
                first.write_text("unchanged")
                second.write_text("second")
                call("single", paths=[first])
                call("multiple", paths=[first, second], options="{'multiple': <true>}")
                call("directory", paths=[root], options="{'directory': <true>}")
                call("cancel")
                target = root / "new.txt"
                options = "{'current_folder': <b'" + str(root) + "'>, 'current_name': <'new.txt'>}"
                call("save", "SaveFile", [target], options)
                call("cancel save", "SaveFile", [], options)
                call("picker error", exit_code=1)

                # A current_name arrives from the calling application, not the picker.
                name = "quote'$(touch INJECTION_MARKER);`touch INJECTION_MARKER`.txt"
                options = "{'current_folder': <b'" + str(root) + "'>, 'current_name': <" + json.dumps(name) + ">}"
                observed = call("literal shell metacharacters", "SaveFile", [root / name], options)
                assert observed["args"][3] == str(root / name), observed
                assert not (root / "INJECTION_MARKER").exists()
                assert first.read_text() == "unchanged"
                assert not target.exists(), "save unexpectedly created a placeholder"
            finally:
                backend.terminate()
                backend.wait(timeout=5)


if __name__ == "__main__":
    main()
