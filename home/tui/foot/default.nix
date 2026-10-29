# Foot is the default Wayland terminal; Stylix supplies fonts, Suzuha supplies colors.
{
  lib,
  pkgs,
  ...
}: let
  glass = (pkgs.formats.ini {}).generate "foot-glass.ini" {
    colors-dark = {
      alpha = 0.92;
      blur = true;
    };
    colors-light = {
      alpha = 0.92;
      blur = true;
    };
  };
in {
  home.sessionVariables.TERMINAL = "foot";

  programs.foot = {
    enable = true;
    settings = {
      main = {
        # Apply opacity after the dynamic palette, which supplies its own alpha.
        include = lib.mkAfter ["${glass}"];
        term = "foot";
        pad = "10x10";
        selection-target = "both";
      };
      scrollback.multiplier = 1;
      mouse.hide-when-typing = true;
      # Foot uses separate windows; retain the familiar shortcut to open one.
      key-bindings.spawn-terminal = "Control+Shift+n Control+Shift+Tab";
      # Keep Ctrl+Backspace distinct from Ctrl+H for terminal applications.
      text-bindings = {
        "\\x1b[127;5u" = "Control+BackSpace";
        "\\x1b[3;5~" = "Control+Delete";
      };
    };
  };
}
