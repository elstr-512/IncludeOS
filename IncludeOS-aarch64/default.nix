{
  nixpkgs ? ../pinned.nix

  # Enable ccache support. See overlay.nix for details.
, withCcache ? false

  # Enable multicore suport.
, smp ? false

, overlays ? [
    ( import ../overlay.nix { inherit withCcache; inherit smp; } )
  ]

, pkgs ? import nixpkgs {
    inherit overlays;
    config = { };
    crossSystem = {
      config = "aarch64-unknown-linux-musl";
    };
  }
}:

let
  inherit (pkgs) pkgsIncludeOS;
in
  assert (pkgsIncludeOS.stdenv.buildPlatform.isLinux == false) ->
    throw "Currently only Linux builds are supported";
  assert (pkgsIncludeOS.stdenv.hostPlatform.isMusl == false) ->
    throw "Stdenv should be based on Musl";

  pkgsIncludeOS.includeos
