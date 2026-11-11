{
  pkgs,
  configDirectory,
}:
pkgs.writeShellScriptBin "nixy"
# bash
''
  set -euo pipefail
  config_directory=${pkgs.lib.escapeShellArg configDirectory}
  # The standalone flake package uses a literal $HOME prefix.
  if [[ "$config_directory" == '$HOME/'* ]]; then
    config_directory="$HOME/''${config_directory#\$HOME/}"
  fi

  function ui(){
    DEFAULT_ICON="󰘳"

    # "icon;name;subcommand"[]; dispatch only entries from this fixed menu.
    apps=(
      "󰑓;Rebuild;rebuild"
      "󰐊;Test;test"
      "󰚰;Update;update"
      ";Collect Garbage;gc"
      "󰍜;Clean Boot Menu;cb"
      ";List generation;listgen"
    )

    # Apply default icons if empty:
    for i in "''${!apps[@]}"; do
      apps[i]=$(echo "''${apps[i]}" | sed 's/^;/'$DEFAULT_ICON';/')
    done

    fzf_result=$(printf "%s\n" "''${apps[@]}" | fzf --delimiter=';' --with-nth=1,2) || exit 0
    [[ -z $fzf_result ]] && exit 0
    for entry in "''${apps[@]}"; do
      if [[ "$entry" == "$fzf_result" ]]; then
        exec "$0" "''${entry##*;}"
      fi
    done
    exit 1
  }

  [[ $# == 0 ]] && ui

  if [[ $1 == "rebuild" ]];then
    cd -- "$config_directory"
    # Add new modules explicitly with git add; never stage local secrets here.
    # Keep builders in the daemon's service, outside the terminal's OOM group.
    sudo env NIX_REMOTE=daemon nixos-rebuild switch --flake . "''${@:2}"
  elif [[ $1 == "test" ]];then
    cd -- "$config_directory"
    sudo env NIX_REMOTE=daemon nixos-rebuild test --flake . "''${@:2}"
  elif [[ $1 == "update" ]];then
    cd -- "$config_directory"
    # Read credentials at runtime; keep them out of the store and command arguments.
    if github_token="$(${pkgs.gh}/bin/gh auth token --hostname github.com 2>/dev/null)" && [[ -n "$github_token" ]]; then
      NIX_CONFIG="''${NIX_CONFIG-}"$'\n'"extra-access-tokens = github.com=$github_token" \
        nix flake update "''${@:2}"
    else
      nix flake update "''${@:2}"
    fi
  elif [[ $1 == "gc" ]];then
    echo "Starting Nix garbage collection..."
    cd -- "$config_directory"
    echo "Cleaning up system garbage..."
    sudo nix-collect-garbage -d
    echo "Cleaning up user garbage..."
    nix-collect-garbage -d
    echo "Collecting garbage from Nix store..."
    nix-store --gc
    echo "Optimizing Nix store..."
    nix-store --optimise
    echo "Nix garbage collection complete."
  elif [[ $1 == "cb" ]];then
    sudo /run/current-system/bin/switch-to-configuration boot
  elif [[ $1 == "listgen" ]];then
    sudo nix-env -p /nix/var/nix/profiles/system --list-generations
  else
    echo "Unknown argument" >&2
    exit 2
  fi
''
