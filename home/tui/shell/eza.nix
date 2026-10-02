# Eza is a ls replacement
{
  programs.fish.interactiveShellInit = ''
    complete -c eza -w ls
  '';
  programs.eza = {
    enable = true;
    icons = "auto";

    extraOptions = [
      "--group-directories-first"
      "--no-quotes"
      "--icons=always"
    ];
  };
}
