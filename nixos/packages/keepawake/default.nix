{pkgs, ...}:
pkgs.writeShellApplication {
  name = "keepawake";
  runtimeInputs = [pkgs.coreutils pkgs.util-linux pkgs.systemd pkgs.libnotify];
  text = ''
    state="''${XDG_RUNTIME_DIR:?}/keepawake.enabled"
    action="''${1:-toggle}"
    case "$action" in
      on|off|toggle) ;;
      status)
        if [[ -e "$state" ]]; then echo on; else echo off; fi
        exit 0
        ;;
      *)
        echo "Usage: keepawake [on|off|toggle|status]" >&2
        exit 2
        ;;
    esac

    # Serialize launcher clicks without persisting the toggle across logins.
    umask 077
    exec 9>"$XDG_RUNTIME_DIR/keepawake.lock"
    flock 9
    if [[ "$action" == toggle ]]; then
      if [[ -e "$state" ]]; then action=off; else action=on; fi
    fi
    if [[ "$action" == on ]]; then
      touch "$state"
      message="Automatic locking, screen-off and idle suspend are paused."
    else
      # Reset elapsed timeouts before allowing idle actions again.
      if ! systemctl --user restart swayidle.service; then
        notify-send --urgency=critical "Keep Awake" "Could not restart idle timers." || true
        exit 1
      fi
      rm -f "$state"
      message="Automatic locking, screen-off and idle suspend are restored."
    fi
    echo "$action"
    notify-send --app-name="Keep Awake" --icon=preferences-desktop-screensaver \
      "Keep Awake: $action" "$message" || true
  '';
}
