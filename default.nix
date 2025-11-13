# ./default.nix
{
  nixpkgs ? ./pinned.nix

, overlays ? [
    ( import ./overlay.nix {} )
  ]

, pkgs ? import nixpkgs {
    overlays = overlays;

    # Target machine (the system for which we are building binaries)
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
