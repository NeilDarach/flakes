{ nixpkgs, ... }: {
  overlays = [
    (final: prev:
      let defaultRust = prev.rust-bin.stable.latest.default;
      in {
        rustToolChain = ((prev.rustRustToolChain or defaultRust).override {
          extensions = prev.rustToolChain.extensions
            ++ [ "rustfmt" "rust-src" ];
          targets = prev.rustToolChain.targets ++ [
            "wasm32-unknown-unknown"
            "aarch64-apple-ios"
            "aarch64-apple-ios-sim"
          ];
        }).overrideAttrs (oldAttrs: {
          ## Modify the rust package to not propagate the wrapped clang packages
          ## binutils-unwrapped provides install_name_tool which installation needs
          propagatedBuildInputs = [ pkgs.darwin.binutils-unwrapped ];
          depsHostHostPropagated = [ ];
          depsTargetTargetPropagated = [ ];
        });

        #The default cc is the wrapped clang from nix.
        #Without this link, rustc finds the wrapped cc and
        #that adds macos specific flags which conflict when
        #cross-compiling for iphone
        #Cribbed from the xcodeenv implementation
        cclink-impure = pkgs.stdenv.mkDerivation {
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
        system-xcode = (import (nixpkgs + "/pkgs/development/mobile/xcodeenv") {
          inherit (pkgs) callPackage;
        }).composeXcodeWrapper { };
      })
  ];

  devShells.aarch64-darwin.dioxus = pkgs.mkShell {
    packages = with pkgs; [
      system-xcode
      dioxus-cli
      rustToolChain
      cclink-impure
    ];
    shellHook = ''
      RUST_SRC_PATH="${pkgs.rustToolChain}/lib/rustlib/src/rust/library";
      #Use the system installation of the SDKs, not the nix-installed version
      unset DEVELOPER_DIR
      unset SDKROOT
    '';
  };
}

