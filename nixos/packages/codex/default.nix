{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  installShellFiles,
  jq,
  zstd,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codex";
  version = "0.167.0";

  # The source build exceeds nixtop's RAM even with one compiler job.
  # Keep the complete upstream bundle, including sandbox and voice helpers.
  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${finalAttrs.version}/codex-package-x86_64-unknown-linux-musl.tar.zst";
    hash = "sha256-n2e4hoixQ1kH4hSIWI/yAR/f8n5YLS05XohVv1Z6jP8=";
  };
  sourceRoot = ".";
  nativeBuildInputs = [autoPatchelfHook installShellFiles jq zstd];
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r bin codex-package.json codex-path codex-resources "$out/"
    installShellCompletion --cmd codex \
      --bash <("$out/bin/codex" completion bash) \
      --fish <("$out/bin/codex" completion fish) \
      --zsh <("$out/bin/codex" completion zsh)
    runHook postInstall
  '';

  # The CLI is static; the voice helper and bundled audio libraries need
  # NixOS loader paths. Refresh their recorded hashes after autoPatchelf.
  preFixup = ''
    refreshCodexHashes() {
      local voice="$out/codex-resources/voice" relative hash
      while IFS= read -r relative; do
        hash=$(sha256sum "$out/$relative" | cut -d ' ' -f 1)
        jq --arg path "$relative" --arg hash "$hash" \
          '.sha256[$path] = $hash' "$voice/manifest.json" > manifest.tmp
        mv manifest.tmp "$voice/manifest.json"
      done < <(jq -r '.sha256 | keys[]' "$voice/manifest.json")
      jq --slurpfile manifest "$voice/manifest.json" \
        '.libraries |= map(.sha256 = $manifest[0].sha256["codex-resources/voice/" + .path])' \
        "$voice/runtime.json" > runtime.tmp
      mv runtime.tmp "$voice/runtime.json"
      hash=$(sha256sum "$voice/runtime.json" | cut -d ' ' -f 1)
      jq --arg hash "$hash" '.sha256["codex-resources/voice/runtime.json"] = $hash' \
        "$voice/manifest.json" > manifest.tmp
      mv manifest.tmp "$voice/manifest.json"
    }
    postFixupHooks+=(refreshCodexHashes)
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/codex" --version | grep -Fx 'codex-cli ${finalAttrs.version}'
    "$out/bin/codex-code-mode-host" --help >/dev/null
    "$out/bin/codex-exec-server" --help >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Codex CLI from the official prebuilt release bundle";
    homepage = "https://github.com/openai/codex";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
