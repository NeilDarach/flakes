{
  description = "Environment for developing rust programs";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
  };

  outputs = inputs@{ nixpkgs, rust-overlay, ... }: {

    nixosModules.default = { config, inputs, pkgs, lib, ... }: {
      options = {
        rustOptions.enabled = lib.mkEnableOption "If rust should be loaded";
        rustOptions.extensions = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Which extensions to include";
        };
      };
      config = {
        overlays = if true then
          final: prev: {
            rustToolChain = let rust = prev.rust-bin;
            in if builtins.pathExists ./rust-toolchain.toml then
              rust.fromRustupToolchainFile ./rust-toolchain.toml
            else if builtins.pathExists ./rust-toolchain then
              rust.fromRustupToolchainFile ./rust-toolchain
            else
              rust.stable.latest.default.override {
                extensions = config.rustOptions.extensions;
              };
          }
        else
          final: prev: { };
      };
    };
  };
}
