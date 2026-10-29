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
          # Firefox Multi-Account Containers
          "@testpilot-containers" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/4867303/multi_account_containers-8.3.8.xpi";
          };
          # Brave search
          "BraveSearchExtension@io.Uvera" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/4278495/brave_search-1.3.0.xpi";
          };
          # TWP - Translate Web Pages
          "{036a55b4-5e72-4d05-a06c-cba2dfcc134a}" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/4962745/traduzir_paginas_web-10.2.1.0.xpi";
          };
          # Terms of Service; Didn’t Read
          "jid0-3GUEt1r69sQNSrca5p8kx9Ezc3U@jetpack" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/4464742/terms_of_service_didnt_read-5.1.1.xpi";
          };
          # Ambient light for YouTube™
          "{60493d8c-aec8-448e-a247-5d2cfa047d69}" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/4618615/ambient_light_for_youtube-2.38.17.xpi";
          };
          # uBlock Origin
          "uBlock0@raymondhill.net" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/5034826/ublock_origin-1.75.0.xpi";
          };
          # I don't care about cookies
          "jid1-KKzOGWgsW3Ao4Q@jetpack" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/4202634/i_dont_care_about_cookies-3.5.0.xpi";
          };
          # Torrent Finder
          "TFToolbarX@torrent-finder" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/3687440/torrent_finder_toolbar-1.0.0.xpi";
          };
          # Decentraleyes
          "jid1-BoFifL9Vbdl2zQ@jetpack" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/4943310/decentraleyes-3.0.2.xpi";
          };
          # Enhancer for YouTube™
          "enhancerforyoutube@maximerf.addons.mozilla.org" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/4933627/enhancer_for_youtube-2.0.136.xpi";
          };
          # NoScript
          "{73a6fe31-595d-460b-a920-fcc0f8843232}" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/5075209/noscript-13.6.36.xpi";
          };
          # Violentmonkey
          "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/5009389/violentmonkey-2.49.0.xpi";
          };
          # Allow Right-Click
          "{278b0ae0-da9d-4cc6-be81-5aa7f3202672}" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/4834120/re_enable_right_click-0.6.9.xpi";
          };
          # ClearURLs
          "{74145f27-f039-47ce-a470-a662b129930a}" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/4432106/clearurls-1.27.3.xpi";
          };
          # Sink It for Reddit
          "{09acf9ff-55d4-4366-a1a9-c9b3c8877c09}" = {
            installation_mode = "force_installed";
            install_url = "https://addons.mozilla.org/firefox/downloads/file/5165967/sink_it_for_reddit-8.14.0.xpi";
          };
        };
      };

      profiles.default = {
        isDefault = true;

        # Extension button order from the current toolbar and extensions panel.
        extensionButtons = {
          "nav-bar" = [
            "uBlock0@raymondhill.net"
            "keepassxc-browser@keepassxc.org"
          ];
          "unified-extensions-area" = [
            "@testpilot-containers"
            "{73a6fe31-595d-460b-a920-fcc0f8843232}"
            "jid1-MnnxcxisBPnSXQ@jetpack"
            "gdpr@cavi.au.dk"
            "addon@darkreader.org"
            "{762f9885-5a13-4abd-9c77-433dcd38b8fd}"
            "foxyproxy@eric.h.jung"
            "{036a55b4-5e72-4d05-a06c-cba2dfcc134a}"
            "jid0-3GUEt1r69sQNSrca5p8kx9Ezc3U@jetpack"
            "{60493d8c-aec8-448e-a247-5d2cfa047d69}"
            "{09acf9ff-55d4-4366-a1a9-c9b3c8877c09}"
            "jid1-KKzOGWgsW3Ao4Q@jetpack"
            "TFToolbarX@torrent-finder"
            "jid1-BoFifL9Vbdl2zQ@jetpack"
            "enhancerforyoutube@maximerf.addons.mozilla.org"
            "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}"
            "{278b0ae0-da9d-4cc6-be81-5aa7f3202672}"
            "{74145f27-f039-47ce-a470-a662b129930a}"
          ];
        };

        # The remaining saved shortcuts match Zen's version 21 defaults.
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

        # Portable preferences only: omit account IDs, sessions, timestamps and migrations.
        settings = {
          "widget.use-xdg-desktop-portal.file-picker" = 1;
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

          # Navigation and language preferences from zen/default/prefs.js.
          "browser.bookmarks.showMobileBookmarks" = true;
          "browser.ctrlTab.sortByRecentlyUsed" = true;
          "browser.translations.neverTranslateLanguages" = "cs";
          "browser.urlbar.suggest.searches" = false;
          "browser.warnOnQuitShortcut" = false;
          "sidebar.visibility" = "hide-on-close";

          # Privacy settings selected in the browser.
          "browser.contentblocking.category" = "custom";
          "network.dns.disablePrefetch" = true;
          "network.http.referer.disallowCrossSiteRelaxingDefault.top_navigation" = true;
          "network.http.speculative-parallel-limit" = 0;
          "network.prefetch-next" = false;
          "nimbus.rollouts.enabled" = false;
          "privacy.annotate_channels.strict_list.enabled" = true;
          "privacy.bounceTrackingProtection.mode" = 1;
          "privacy.clearOnShutdown.offlineApps" = true;
          "privacy.clearOnShutdown.siteSettings" = true;
          "privacy.clearOnShutdown_v2.formdata" = true;
          "privacy.clearOnShutdown_v2.siteSettings" = true;
          "privacy.fingerprintingProtection" = true;
          "privacy.query_stripping.enabled" = true;
          "privacy.query_stripping.enabled.pbmode" = true;
          "privacy.trackingprotection.allow_list.convenience.enabled" = false;
          "privacy.trackingprotection.consentmanager.skip.pbmode.enabled" = false;
          "privacy.trackingprotection.emailtracking.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;

          # Keep password handling in KeePassXC.
          "signon.autofillForms" = false;
          "signon.generation.enabled" = false;
          "signon.management.page.breach-alerts.enabled" = false;

          # Appearance and media; fonts and reader colors are supplied by Stylix.
          "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
          "extensions.pictureinpicture.enable_picture_in_picture_overrides" = true;
          "zen.library.media.enabled" = true;
          "zen.theme.hide-unified-extensions-button" = false;

          # New-tab preferences.
          "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = true;
          "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = true;
          "browser.newtabpage.activity-stream.system.showWeatherOptIn" = false;
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
