# ./default.nix
{
  nixpkgs ? ./pinned.nix

, overlays ? [
    ( import ./overlay.nix {} )
  ]

, pkgs ? import nixpkgs {
    overlays = overlays;

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

assert (pkgs.pkgsIncludeOS.stdenv.buildPlatform.isLinux == false) ->
throw "Currently only Linux builds are supported";

assert (pkgs.pkgsIncludeOS.stdenv.hostPlatform.isMusl == false) ->
throw "Stdenv should be based on Musl";

pkgs.pkgsIncludeOS.includeos
