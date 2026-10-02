# My shell configuration
{pkgs, ...}: {
  home.packages = with pkgs; [
    bat
    mmv
    ripgrep
  ];

  home.sessionVariables = {
    COLORTERM = "truecolor";
    MANPAGER = "bat -l man -p";
  };

  programs.fish = {
    enable = true;

    shellAliases = {
      # Change default
      vim = "nvim";
      vi = "nvim";
      cd = "z";
      ls = "eza --icons=always --no-quotes";
      tree = "eza --icons=always --tree --no-quotes";
      mkdir = "mkdir -p";
      nix-shell = "nix-shell --command fish";
      grep = "rg --color=auto";
      diff = "diff --color=auto";
      df = "df -h";

      # Shortcuts
      spt = "myx";
      open = "${pkgs.xdg-utils}/bin/xdg-open";
      zmv = "mmv";

      notes = "nvim ~/Notes/index.md --cmd 'cd ~/notes' -c ':lua Snacks.picker.smart()'";

      # Git
      g = "lazygit";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gpl = "git pull";
      gs = "git status";
      gd = "git diff";
      gco = "git checkout";
      gcb = "git checkout -b";
      gbr = "git branch";
      grs = "git reset HEAD~1";
      grh = "git reset --hard HEAD~1";
      gaa = "git add .";
      gcm = "git commit -m";

      # Original binaries
      ocat = "/run/current-system/sw/bin/cat";
      ols = "/run/current-system/sw/bin/ls";
      ocd = "builtin cd";

      # Typos
      clera = "clear";
      celar = "clear";
      claer = "clear";
      sl = "ls";
    };

    functions = {
      cat = {
        description = "Preview images inline and display other files with bat";
        body = ''
          set -l imgs
          set -l rest

          for file in $argv
            switch (string lower -- "$file")
              case '*.png' '*.jpg' '*.jpeg' '*.gif' '*.bmp' '*.webp' '*.tiff' '*.ico'
                set --append imgs "$file"
              case '*'
                set --append rest "$file"
            end
          end

          for file in $imgs
            chafa --format=kitty "$file"
          end

          if test (count $rest) -gt 0; or test (count $imgs) -eq 0
            bat --theme=base16 --color=always --paging=never --tabs=2 --wrap=never --plain $rest
          end
        '';
      };

      fish_should_add_to_history = {
        argumentNames = ["command"];
        description = "Keep commands beginning with a space out of history";
        body = ''
          string match --quiet --regex '^ ' -- "$command"
          and return 1
          return 0
        '';
      };

      __suffix_editor.body = ''
        printf 'nvim %s' (string escape -- "$argv[1]")
      '';

      __suffix_jless.body = ''
        printf 'jless %s' (string escape -- "$argv[1]")
      '';

      __suffix_tabiew.body = ''
        printf 'tw %s' (string escape -- "$argv[1]")
      '';

      __suffix_open.body = ''
        printf 'xdg-open %s' (string escape -- "$argv[1]")
      '';
    };

    interactiveShellInit = ''
      set --global fish_greeting

      fish_vi_key_bindings
      set --global fish_cursor_default block
      set --global fish_cursor_insert line
      set --global fish_cursor_replace_one underscore
      set --global fish_cursor_visual block

      # Suffix aliases, implemented as command-position abbreviations.
      abbr --add --global suffix_editor --position command --regex '.*\.(nix|md|txt|yml|yaml|go)$' --function __suffix_editor
      abbr --add --global suffix_jless --position command --regex '.*\.(json|jsonl)$' --function __suffix_jless
      abbr --add --global suffix_tabiew --position command --regex '.*\.(csv|tsv|parquet|pqt|arrow|db|sqlite|xls|xlsx|xlsm|xlsb|fwf)$' --function __suffix_tabiew
      abbr --add --global suffix_open --position command --regex '.*\.(png|jpg|jpeg|gif|pdf)$' --function __suffix_open

      # Global aliases, implemented as anywhere abbreviations.
      abbr --add --global --position anywhere G -- '| rg'
      abbr --add --global --position anywhere L -- '| less'
      abbr --add --global --position anywhere V -- '| nvim'
      abbr --add --global --position anywhere H -- '| head'
      abbr --add --global --position anywhere T -- '| tail'
      abbr --add --global --position anywhere JQ -- '| jq'
      abbr --add --global --position anywhere C -- '| wl-copy'
      abbr --add --global --position anywhere NE -- '2>/dev/null'
      abbr --add --global --position anywhere ND -- '>/dev/null'
      abbr --add --global --position anywhere NUL -- '>/dev/null 2>&1'

      bind --mode insert \e\[1\;5C forward-word
      bind --mode insert \e\[1\;5D backward-word
      bind --mode insert \cf _fzf_file_no_hidden
      bind --mode insert \e\[A history-search-backward
      bind --mode insert \e\[B history-search-forward
    '';
  };
}
