{
  inputs,
  pkgs,
  lib,
  ...
}: let
  amane = inputs.amane.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
  amane.overrideAttrs (old: {
    pname = "suzuha";
    version = "0-unstable-${inputs.suzuha.shortRev or "dirty"}";
    __intentionallyOverridingVersion = true;

    # Build Suzuha as Amane's example workspace member. This reuses the exact
    # library and dependency lock shipped with the CLI, without network access
    # or a compilation step at login.
    postPatch =
      (old.postPatch or "")
      + ''
        cp -r ${inputs.suzuha}/src cli/template/example/suzuha
        chmod -R u+w cli/template/example/suzuha
        patch -p1 < ${./suzuha-auth.patch}
        patch -p1 < ${./suzuha-workspaces.patch}
        patch -p1 < ${./suzuha-shortcuts.patch}
        patch -p1 < ${./suzuha-clipboard.patch}
        cp ${./amane-tray.rs} src/tray.rs
        cp ${./suzuha-tray.rs} cli/template/example/suzuha/bar/tray.rs
        substituteInPlace src/lib.rs --replace-fail 'mod dbus;' 'mod dbus; pub mod tray;'
        substituteInPlace src/dbus.rs --replace-fail 'mod convert;' 'pub(crate) mod convert;'
        substituteInPlace src/services.rs --replace-fail 'mod apps;' 'pub(crate) mod apps;'
        substituteInPlace src/services/apps.rs --replace-fail 'mod icons;' 'pub(crate) mod icons;'
        substituteInPlace cli/template/example/suzuha/main.rs \
          --replace-fail 'drop(Notifications::read());' 'drop(Notifications::read()); drop(amane::tray::Tray::read());' \
          --replace-fail '.lock(lock_screen::view)' '.window_per_monitor(bar::tray::dismiss).window_per_monitor(bar::tray::popup).ipc("tray", bar::tray::ipc).lock(lock_screen::view)'
        substituteInPlace cli/template/example/suzuha/bar.rs \
          --replace-fail 'mod system;' 'mod system; pub mod tray;' \
          --replace-fail 'system::view(&theme, third)' 'system::view(&theme, third, monitor)'
        substituteInPlace cli/template/example/suzuha/bar/system.rs \
          --replace-fail 'pub fn view(theme: &Theme, width: f32)' 'pub fn view(theme: &Theme, width: f32, monitor: &amane::Monitor)' \
          --replace-fail 'items.push(Box::new(tray(theme)));' 'if let Some(icons) = super::tray::icons(theme, monitor, width) { items.push(Box::new(icons)); } items.push(Box::new(tray(theme)));'
        cp ${./suzuha-clipboard.rs} cli/template/example/suzuha/overlay/launcher/clipboard.rs
        substituteInPlace cli/template/example/suzuha/overlay/launcher/clipboard.rs \
          --replace-fail '@cliphist@' '${pkgs.cliphist}/bin/cliphist' \
          --replace-fail '@wlcopy@' '${pkgs.wl-clipboard}/bin/wl-copy'
        cp ${./suzuha-focus.rs} cli/template/example/suzuha/focus.rs
        cp ${./suzuha-niri-colors.rs} cli/template/example/suzuha/integrations/niri.rs
        substituteInPlace cli/template/example/suzuha/integrations.rs \
          --replace-fail 'mod gtk;' 'mod gtk; mod niri;' \
          --replace-fail 'self.written = fingerprint;' 'niri::export(&theme); self.written = fingerprint;'
        substituteInPlace src/services/lock/fingerprint.rs \
          --replace-fail '@pamtester@' '${pkgs.pamtester}/bin/pamtester'
        cat >> cli/template/example/Cargo.toml <<'EOF'

        [[bin]]
        name = "amane-example"
        path = "suzuha/main.rs"
        EOF
          substituteInPlace src/services/lock.rs \
            --replace-fail 'const PAM_SERVICE: &str = "login";' 'const PAM_SERVICE: &str = "amane";'
      '';
    cargoBuildFlags = ["-p" "amane-cli" "-p" "amane-example"];
    # These authentication tests use isolated PAM fixtures, not a compositor or
    # real credentials. Cover cancellation, concurrent methods and stale results.
    doCheck = true;
    checkPhase = ''
      runHook preCheck
      # Nix's build sandbox has no login environment. Fixtures use fake PAM
      # policies, but the locker still needs a current-user identity to test.
      export USER=amane-test-user
      cargo test --offline --release --target ${pkgs.stdenv.hostPlatform.rust.rustcTarget} -p amane --lib services::pam::tests
      cargo test --offline --release --target ${pkgs.stdenv.hostPlatform.rust.rustcTarget} -p amane --lib services::lock::fingerprint::tests
      cargo test --offline --release --target ${pkgs.stdenv.hostPlatform.rust.rustcTarget} -p amane-example --bin amane-example overlay::launcher::clipboard::tests
      ${pkgs.dbus}/bin/dbus-run-session -- cargo test --offline --release --target ${pkgs.stdenv.hostPlatform.rust.rustcTarget} -p amane --lib tray::tests
      runHook postCheck
    '';
    postInstall =
      (old.postInstall or "")
      + ''
        mv $out/bin/amane-example $out/bin/suzuha
      '';
    postFixup =
      (old.postFixup or "")
      + ''
        wrapProgram $out/bin/suzuha \
          --prefix PATH : ${lib.makeBinPath (with pkgs; [
          brightnessctl
          cava
          curl
          dconf
          ffmpeg
          foot
          imagemagick
          libnotify
          networkmanager
          niri
          pipewire
          procps
          pulseaudio
          systemd
          tmux
          wf-recorder
          xdg-utils
        ])} \
          --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath (with pkgs; [vulkan-loader wayland])}
      '';
    meta =
      (old.meta or {})
      // {
        description = "Suzuha desktop shell for Niri, built with Amane";
        homepage = "https://github.com/MystiaFin/suzuha";
        mainProgram = "suzuha";
      };
  })
