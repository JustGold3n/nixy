{
  lib,
  pkgs,
  config,
  ...
}: {
  options.theme = lib.mkOption {
    type = lib.types.attrs;
    default = {
      rounding = 20;
      bar-height = 36;
      gaps-in = 8;
      gaps-out = 8 * 2;
      active-opacity = 1.0;
      inactive-opacity = 0.92;
      blur = true;
      border-size = 2;
      animation-speed = "fast"; # "very-fast" | "fast" | "medium" | "slow"
    };
    description = "Theme configuration options";
  };

  config.stylix = {
    enable = true;

    # See https://tinted-theming.github.io/tinted-gallery/ for more schemes
    base16Scheme = {
      base00 = "000000"; # Default Background
      base01 = "121212"; # Lighter Background (Used for status bars, line number and folding marks)
      base02 = "222222"; # Selection Background
      base03 = "333333"; # Comments, Invisibles, Line Highlighting
      base04 = "999999"; # Dark Foreground (Used for status bars)
      base05 = "c1c1c1"; # Default Foreground, Caret, Delimiters, Operators
      base06 = "999999"; # Light Foreground (Not often used)
      base07 = "c1c1c1"; # Light Background (Not often used)
      base08 = "5f8787"; # Variables, XML Tags, Markup Link Text, Markup Lists, Diff Deleted
      base09 = "aaaaaa"; # Integers, Boolean, Constants, XML Attributes, Markup Link Url
      base0A = "eecc6c"; # Classes, Markup Bold, Search Text Background
      base0B = "f3ecd4"; # Strings, Inherited Class, Markup Code, Diff Inserted
      base0C = "aaaaaa"; # Support, Regular Expressions, Escape Characters, Markup Quotes
      base0D = "888888"; # Functions, Methods, Attribute IDs, Headings, Accent color
      base0E = "999999"; # Keywords, Storage, Selector, Markup Italic, Diff Changed
      base0F = "444444"; # Deprecated, Opening/Closing Embedded Language Tags, e.g. <?php ?>
    };

    cursor = {
      name = "BreezeX-RosePine-Linux";
      package = pkgs.rose-pine-cursor;
      size = 20;
    };

    fonts = {
      monospace = {
        package = pkgs.maple-mono.NF;
        name = "Maple Mono NF";
      };
      sansSerif = {
        package = pkgs.rubik;
        name = "Rubik";
      };
      serif = config.stylix.fonts.sansSerif;
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        applications = 13;
        desktop = 13;
        popups = 13;
        terminal = 13;
      };
    };

    polarity = "dark";
    image = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/anotherhadi/awesome-wallpapers/main/wallpapers/another-one.png";
      sha256 = "sha256-bKke8RNz6qNxHSfLbU5xVVkG3tbFZW1sFjLB1hltcoI=";
    };
  };
}
