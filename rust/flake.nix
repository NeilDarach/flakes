{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    flake-utils = { url = "github:numtide/flake-utils"; };
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };

  };

  outputs = { nixpkgs, rust-overlay, ... }: {
    overlays.default = [
      (import rust-overlay)
      (prev: final: {
        rustToolChain = let rust = prev.rust-bin;
        in if builtins.pathExists ./rust-toolchain.toml then
          rust.fromRustupToolchainFile ./rust-toolchain.toml
        else if builtins.pathExists ./rust-toolchain then
          rust.fromRustupToolchainFile ./rust-toolchain
        else
          rust.stable.latest.default.override {
            extensions = [ "rust-src" "rustfmt" ];
          };

      })
    ];
    makeDevShell = (pkgs: definition:
      pkgs.mkShell (pkgs.lib.updateManyAttrsByPath [

        {
          path = [ "parameters" ];
          update = old: (definition.packages or []) ++ [ pkgs.rustToolChain pkgs.just pkgs.bacon ];
        }
        {
          path = [ "env" ];
          update = old:
            {
              RUST_SRC_PATH =
                "${pkgs.rustToolChain}/lib/rustlib/src/rust/library";
            } // (definition.env or {});
        }
      ] definition));
  };
}
