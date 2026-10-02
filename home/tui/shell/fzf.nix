# Fzf is a general-purpose command-line fuzzy finder.
{
  config,
  lib,
  ...
}: let
  accent = "#" + config.lib.stylix.colors.base0D;
  foreground = "#" + config.lib.stylix.colors.base05;
  muted = "#" + config.lib.stylix.colors.base03;
  previewCmd = "bat --color=always --style=plain,numbers --line-range=:500 {}";
in {
  programs.fzf = {
    enable = true;
    enableFishIntegration = true;

    defaultCommand = "fd --type f --hidden --strip-cwd-prefix";
    fileWidgetCommand = "fd --type f --hidden --strip-cwd-prefix";
    fileWidgetOptions = ["--preview '${previewCmd}'"];

    colors = lib.mkForce {
      "fg+" = accent;
      "bg+" = "-1";
      "fg" = foreground;
      "bg" = "-1";
      "prompt" = muted;
      "pointer" = accent;
      "border" = muted;
      "preview-border" = muted;
      "scrollbar" = muted;
      "preview-scrollbar" = muted;
      "gutter" = muted;
    };

    defaultOptions = [
      "--height=60%"
      "--layout=reverse"
      "--border=none"
      "--prompt='/ '"
      "--preview-window=right:65%:wrap:border-left"
      "-i"
      "--no-bold"
    ];
  };

  programs.fish.functions._fzf_file_no_hidden = {
    description = "Find files without including hidden files";
    body = ''
      set -l cmd (string replace -- "--hidden " "" "$FZF_DEFAULT_COMMAND")
      if test -z "$cmd"
        set cmd "find . -type f"
      end

      set -l result (eval "$cmd" | fzf --preview "${previewCmd}")
      if test $status -eq 0
        commandline --insert -- (string escape -- "$result")
      end
      commandline --function repaint
    '';
  };
}
