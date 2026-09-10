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
  # cross compile configured nix packages
  supportedTargets.pkgs = {
    x86_64 = import nixpkgs {
      overlays = overlays;
      crossSystem = { config = "x86_64-unknown-linux-musl"; };
    };

    aarch64 = import nixpkgs {
      overlays = overlays;
      crossSystem = { config = "aarch64-unknown-linux-musl"; };
    };

    i686 = import nixpkgs {
      overlays = overlays;
      crossSystem = { config = "i686-unknown-linux-musl"; };
    };
  };

  # Select pkgs configuration
  pkgs = supportedTargets.pkgs.${target};

in
  assert (pkgsIncludeOS.stdenv.buildPlatform.isLinux == false) ->
    throw "Currently only Linux builds are supported";
  assert (pkgsIncludeOS.stdenv.hostPlatform.isMusl == false) ->
    throw "Stdenv should be based on Musl";

pkgs.pkgsIncludeOS.includeos
