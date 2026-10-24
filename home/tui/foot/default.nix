# Foot is the default Wayland terminal; Stylix supplies its fonts and colors.
{...}: {
  home.sessionVariables.TERMINAL = "foot";

  programs.foot = {
    enable = true;
    settings = {
      main = {
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
