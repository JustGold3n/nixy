{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  startpage = "http://127.0.0.1:8888";
in {
  imports = [
    inputs.zen-browser.homeModules.twilight
    ../../lib/browser-startpage
  ];

  config = lib.mkIf ((config.var.hostname or "") == "nixtop") {
    stylix.targets.zen-browser.profileNames = ["default"];

    programs.zen-browser = {
      enable = true;
      enablePrivateDesktopEntry = true;
      setAsDefaultBrowser = true;

      activationFragments.default = [
        {
          priority = 110;
          requiresLock = true;
          skipSubject = "copy shortcut action";
          text = let
            shortcutsFile = "${config.xdg.configHome}/zen/default/zen-keyboard-shortcuts.json";
          in ''
            if [[ -f ${lib.escapeShellArg shortcutsFile} ]]; then
              shortcuts_tmp="$(${pkgs.coreutils}/bin/mktemp ${lib.escapeShellArg "${shortcutsFile}.XXXXXX"})"
              ${lib.getExe pkgs.jq} '(.shortcuts[] | select(.id == "zen-copy-url")).action = "cmd_copy"' \
                ${lib.escapeShellArg shortcutsFile} > "$shortcuts_tmp"
              ${pkgs.coreutils}/bin/mv "$shortcuts_tmp" ${lib.escapeShellArg shortcutsFile}
            fi
          '';
        }
      ];

      policies = {
        AutofillAddressEnabled = false;
        AutofillCreditCardEnabled = false;
        DisableFeedbackCommands = true;
        DisableFirefoxAccounts = false;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DontCheckDefaultBrowser = true;
        NoDefaultBookmarks = lib.mkForce true;
        OfferToSaveLogins = false;
        PasswordManagerEnabled = false;

        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };

        Homepage = {
          URL = startpage;
          StartPage = "previous-session";
        };

        DNSOverHTTPS = {
          Enabled = true;
          ProviderURL = "https://dns.quad9.net/dns-query";
          Locked = true;
        };

        Permissions = {
          Location.BlockNewRequests = true;
          Notifications.BlockNewRequests = true;
        };

        ExtensionSettings = {
          "foxyproxy@eric.h.jung" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/foxyproxy-standard/latest.xpi";
          };
          "keepassxc-browser@keepassxc.org" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/keepassxc-browser/latest.xpi";
          };
          "gdpr@cavi.au.dk" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/consent-o-matic/latest.xpi";
          };
          "jid1-MnnxcxisBPnSXQ@jetpack" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/privacy-badger17/latest.xpi";
          };
          "addon@darkreader.org" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/darkreader/latest.xpi";
          };
          "{762f9885-5a13-4abd-9c77-433dcd38b8fd}" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/return-youtube-dislikes/latest.xpi";
          };
        };
      };

      profiles.default = {
        isDefault = true;

        keyboardShortcuts = [
          {
            id = "zen-copy-url";
            key = "c";
            modifiers = {
              accel = true;
              alt = false;
              control = false;
              meta = false;
              shift = true;
            };
          }
          {
            id = "key_quitApplication";
            disabled = true;
          }
          {
            id = "key_close";
            key = "q";
            modifiers = {
              accel = true;
              alt = false;
              control = false;
              meta = false;
              shift = false;
            };
          }
        ];
        keyboardShortcutsVersion = 21;

        settings = {
          "browser.startup.homepage" = startpage;
          "browser.startup.page" = 3;
          "browser.toolbars.bookmarks.visibility" = "never";
          "full-screen-api.enabled" = true;
          "full-screen-api.transition-duration.enter" = "0 0";
          "full-screen-api.transition-duration.leave" = "0 0";
          "media.ffmpeg.vaapi.enabled" = true;
          "privacy.donottrackheader.enabled" = true;
          "zen.urlbar.behavior" = "float";
          "zen.welcome-screen.seen" = true;
          "zen.workspaces.continue-where-left-off" = true;
        };

        search = {
          force = true;
          default = "startpage";
          privateDefault = "startpage";
          engines.startpage = {
            name = "Startpage";
            urls = [{template = "https://www.startpage.com/do/search?q={searchTerms}";}];
            definedAliases = ["@sp"];
          };
        };
      };
    };

    home.persistence."/persist" = lib.mkIf (config.var.impermanenceEnabled or false) {
      directories = [
        ".config/zen"
        ".pki" # NSS database (client certificates)
      ];
    };
  };
}
