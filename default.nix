{
  nixpkgs ? ./pinned.nix,

  overlays ? [
    ( import ./overlay.nix {inherit withCcache smp;} )
  ],

  # Which architecture to build against,
  # can be passed via command line: --argstr target <string>
  target ? "x86_64",

  # Enable ccache support. See overlay.nix for details.
  withCcache ? false,

  # Enable multicore suport (SMP).
  # WARN:
  # While the SMP flag exists in the nix-config,
  # it is currently always defined as ON in CMakelists.txt
  smp ? false,
}:

let
  inherit (pkgs) pkgsIncludeOS;
in
  assert (pkgsIncludeOS.stdenv.buildPlatform.isLinux == false) ->
    throw "Currently only Linux builds are supported";
  assert (pkgsIncludeOS.stdenv.hostPlatform.isMusl == false) ->
    throw "Stdenv should be based on Musl";

  pkgsIncludeOS.includeos
