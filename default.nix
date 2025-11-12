# ./default.nix
{
  nixpkgs ? ./pinned.nix

, overlays ? [
    ( import ./overlay.nix {} )
  ]

, pkgs ? import nixpkgs {
    crossOverlays = overlays;

    # Build machine (the system running nix-build)
    buildSystem = "x86_64-linux";

    # Host machine (the system the compiler runs on)
    #
    # WARN: need to specify musl for the stdenv, even
    #       when buildSystem and crossSystem is the same,
    #       i.e. when we are not cross-compiling.
    localSystem = {
      system = "x86_64-linux";
      config = "x86_64-unknown-linux-musl";
    };

    # Kernel target machine (the system for which we are building binaries)
    #
    # NOTE: remove this for x86 builds.
    crossSystem = {
      config = "aarch64-unknown-linux-musl";
    };

  }
}:

pkgs.pkgsIncludeOS.includeos
