{ pkgs, lib, ... }:

{
  packages = with pkgs; [
    just

    cargo-audit
    cargo-deny
    cargo-hack
    cargo-release
    cargo-watch

    # lld, in place of `languages.rust.lld.enable`: see `env` below.
    lld
  ];

  # dx for the demo, and wasm-bindgen-test-runner for the browser tests.
  # The demo and the workspace lock the same wasm-bindgen version.
  dioxus = {
    enable = true;
    cargoLock = ./demo/Cargo.lock;

    # `devenv up` serves the demo.
    serve = {
      enable = true;
      directory = "demo";
      extraArgs = [
        "--fullstack"
        "@client"
        "--platform"
        "web"
        "--no-default-features"
        "--features"
        "web"
        "@server"
        "--platform"
        "server"
        "--no-default-features"
        "--features"
        "server"
      ];
    };
  };

  languages = {
    rust = {
      enable = true;
      channel = "stable";
      targets = [ "wasm32-unknown-unknown" ];

      # Doesn't work with wasm
      # lld.enable = true;
    };

    javascript = {
      enable = true;

      npm.enable = true;
    };
  };

  profiles = {
    # The minimum supported Rust version, in place of the latest stable.
    msrv.module = {
      languages.rust.version = lib.mkForce (
        lib.versions.pad 3 (fromTOML (builtins.readFile ./Cargo.toml)).workspace.package.rust-version
      );
    };
  };
}
