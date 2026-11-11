{
  lib,
  rustPlatform,
  zenity,
}:
rustPlatform.buildRustPackage {
  pname = "nixy-tools";
  version = "0.1.0";
  src = lib.fileset.toSource {
    root = ../../..;
    fileset = lib.fileset.unions [
      ../../../Cargo.toml
      ../../../Cargo.lock
      ../../../rust
      ../../../.github/scripts/inject-exec.rs
      (lib.fileset.fileFilter (file: file.hasExt "rs") ../../../home/system)
      ../../../home/tui/nixy/test-nixy.rs
      (lib.fileset.fileFilter (file: file.hasExt "rs") ../../battery-care)
      ../loaf/test-chooser.rs
      ../termfilechooser/test-termfilechooser.rs
    ];
  };
  cargoLock.lockFile = ../../../Cargo.lock;
  NIXY_ZENITY = "${zenity}/bin/zenity";
  doCheck = true;
  meta.description = "Local desktop, battery and maintenance tools for Nixy";
}
