"""Exercise the patched Loaf picker without opening windows in the user session.

Run: python3 nixos/packages/loaf/test-chooser.py /nix/store/...-loaf-0.2.0/bin/loaf
"""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


def check(binary, root, name, paths, *, multiple=False, directory=False,
          save=False, rejected=False, cancel=False, ui=False, confirm=False):
    output = root / "selection"
    output.write_text("")
    probe = root / "probe.qml"
    action = "Qt.quit();" if cancel else f"""
        var error = native.acceptChoice({json.dumps([str(p) for p in paths])});
        console.log("CHOOSER_RESULT=" + JSON.stringify(error));
        Qt.quit();
    """
    setup = ""
    if ui:
        setup = """
    property var picker
    Component.onCompleted: {
        var component = Qt.createComponent("qrc:/qt/qml/app/loaf/qml/main.qml");
        if (component.status !== Component.Ready) {
            console.error(component.errorString());
            Qt.quit();
            return;
        }
        picker = component.createObject(null);
    }
"""
        action = """
        if (!picker || !picker.chooser.enabled)
            throw new Error("Picker window failed to load");
        console.log('CHOOSER_RESULT=""');
        ACTION
""".replace("ACTION", "picker.close(); Qt.quit();" if cancel else f"""
        picker.activePane.selectPaths({json.dumps([str(p) for p in paths])});
        picker.acceptChoice();
""")
        if confirm:
            action += """
        if (!picker.anyModalOpen)
            throw new Error("Overwrite confirmation did not open");
        picker.close();
        Qt.quit();
"""
    probe.write_text("""
import QtQuick
Item {
    SETUP
    Timer {
        interval: 1000
        running: true
        onTriggered: { ACTION }
    }
}
""".replace("SETUP", setup).replace("ACTION", action))
    env = os.environ | {
        "QT_QPA_PLATFORM": "offscreen",
        "QT_QUICK_BACKEND": "software",
        "QT_FORCE_STDERR_LOGGING": "1",
        "XDG_CONFIG_HOME": str(root / "config"),
        "XDG_CACHE_HOME": str(root / "cache"),
        "XDG_DATA_HOME": str(root / "data"),
        "LOAF_QML": str(probe),
        "LOAF_VERBOSE": "1",
        "LOAF_CHOOSER_OUTPUT": str(output),
        "LOAF_CHOOSER_MULTIPLE": str(int(multiple)),
        "LOAF_CHOOSER_DIRECTORY": str(int(directory)),
        "LOAF_CHOOSER_SAVE": str(int(save)),
        "LOAF_CHOOSER_NAME": paths[0].name if save else "",
    }
    result = subprocess.run([binary, "--new-window", str(root)], env=env,
                            capture_output=True, text=True, timeout=20)
    assert result.returncode == 0, (name, result.stderr)
    if not cancel:
        marker = 'CHOOSER_RESULT=""'
        assert (marker not in result.stderr) == rejected, (name, result.stderr)
        assert "CHOOSER_RESULT=" in result.stderr, (name, result.stderr)
    expected = "" if rejected or cancel or confirm else "".join(str(p) + "\n" for p in paths)
    assert output.read_text() == expected, (name, output.read_text())
    print(f"PASS: {name}")


def main():
    binary = sys.argv[1]
    with tempfile.TemporaryDirectory(prefix="loaf-picker-test-") as tmp:
        root = Path(tmp)
        first = root / "žluťoučký file's name.txt"
        second = root / "second.txt"
        for path in (first, second):
            path.write_text("original content")
        folder = root / "folder"
        folder.mkdir()
        check(binary, root, "single file with spaces, quotes and Czech text", [first])
        check(binary, root, "multiple files", [first, second], multiple=True)
        check(binary, root, "single mode rejects multiple files", [first, second], rejected=True)
        check(binary, root, "directory", [folder], directory=True)
        check(binary, root, "file mode rejects directory", [folder], rejected=True)
        check(binary, root, "directory mode rejects file", [first], directory=True, rejected=True)
        check(binary, root, "missing file", [root / "missing"], rejected=True)
        check(binary, root, "relative path", [Path("relative")], rejected=True)
        check(binary, root, "line breaks", [root / "bad\nname"], save=True, rejected=True)
        destination = root / "new file.txt"
        check(binary, root, "save new file", [destination], save=True)
        assert not destination.exists(), "Picker must not create the destination"
        check(binary, root, "save existing file", [first], save=True)
        assert first.read_text() == "original content", "Picker must not overwrite files"
        check(binary, root, "save missing parent", [root / "missing" / "file"], save=True, rejected=True)
        check(binary, root, "cancel", [], cancel=True)
        check(binary, root, "picker UI: single file", [first], ui=True)
        check(binary, root, "picker UI: multiple files", [first, second], multiple=True, ui=True)
        check(binary, root, "picker UI: folder", [folder], directory=True, ui=True)
        check(binary, root, "picker UI: current folder", [root], directory=True, ui=True)
        check(binary, root, "picker UI: save new file", [destination], save=True, ui=True)
        assert not destination.exists()
        check(binary, root, "picker UI: overwrite confirmation", [first], save=True, ui=True, confirm=True)
        assert first.read_text() == "original content"
        check(binary, root, "picker UI: cancel", [], cancel=True, ui=True)


if __name__ == "__main__":
    main()
