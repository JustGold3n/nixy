# Import all shell configurations
{
  imports = [
    ./fzf.nix
    ./fish.nix
    ./starship.nix
    ./zoxide.nix
    ./eza.nix
    ./direnv.nix
  ];

  # Word deletion in Bash and other Readline-based terminal prompts.
  programs.readline = {
    enable = true;
    bindings = {
      "\\e[127;5u" = "backward-kill-word";
      "\\e[3;5~" = "kill-word";
    };
  };
}
