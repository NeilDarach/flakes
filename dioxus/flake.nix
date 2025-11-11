{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };
  };
  outputs = { rust-overlay, nixpkgs, ... }:
    let inherit (nixpkgs) lib;
    in {
      overlays = [
        (import rust-overlay)
        (final: prev:
          let
            inherit (nixpkgs) lib;
            defaultRust = prev.rust-bin.stable.latest.default;
          in {
            rustToolChain = ((prev.rustRustToolChain or defaultRust).override {
              extensions = (prev.rustToolChain.extensions or [ ])
                ++ [ "rustfmt" "rust-src" ];
              targets = (prev.rustToolChain.targets or [ ]) ++ [
                "wasm32-unknown-unknown"
                "aarch64-apple-ios"
                "aarch64-apple-ios-sim"
              ];
            }).overrideAttrs (oldAttrs: {
              ## Modify the rust package to not propagate the wrapped clang packages
              ## binutils-unwrapped provides install_name_tool which installation needs
              propagatedBuildInputs = [ final.darwin.binutils-unwrapped ];
              depsHostHostPropagated = [ ];
              depsTargetTargetPropagated = [ ];
            });

            #The default cc is the wrapped clang from nix.
            #Without this link, rustc finds the wrapped cc and
            #that adds macos specific flags which conflict when
            #cross-compiling for iphone
            #Cribbed from the xcodeenv implementation
            cclink-impure = final.stdenv.mkDerivation {
              name = "cclink-impure";
              # Fails in sandbox. Use `--option sandbox relaxed` or `--option sandbox false`.
              __noChroot = true;
              buildCommand = ''
                mkdir -p $out/bin
                cd $out/bin
                ln -s "${final.system-xcode}/bin/clang" cc
              '';
            };
            # Create symlinks to the system XCode installation
            system-xcode =
              (import (nixpkgs + "/pkgs/development/mobile/xcodeenv") {
                inherit (final) callPackage;
              }).composeXcodeWrapper { };
          })
      ];

      # Take an attribute set suitable for mkShell and ensure that
      # the required packages and shell hook are added to any that
      # already exist
      addToShell = pkgs: shell:
        let
          base = {
            # ensure a default if the caller doesn't set values
            packages = [ ];
            shellHook = "";
          } // shell;
          hook = ''
            export RUST_SRC_PATH="${pkgs.rustToolChain}/lib/rustlib/src/rust/library";
            #Use the system installation of the SDKs, not the nix-installed version
            unset DEVELOPER_DIR
            unset SDKROOT
          '';
        in lib.updateManyAttrsByPath [
          {
            path = [ "packages" ];
            update = old:
              (old ++ (with pkgs; [
                system-xcode
                dioxus-cli
                rustToolChain
                cclink-impure
              ]));
          }
          {
            path = [ "shellHook" ];
            update = old: old + hook;
          }
        ] base;

    };
}
