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
  # default nix packages, so we can perform asserts even if provided target doesn't exist
  defaultNixpkgs = import nixpkgs {};

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

  # assert helpers
  supportedTargets.name = [
    "x86_64"
    "aarch64"
    "i686"
  ];

  supportedTargets.system = [
    "x86_64-linux"
    "aarch64-linux"
    "i686-linux"
  ];

  assertMsg      = defaultNixpkgs.lib.asserts.assertMsg;
  assertOneOf    = defaultNixpkgs.lib.asserts.assertOneOf;

  buildPlatform  = pkgs.pkgsIncludeOS.stdenv.buildPlatform;
  compilerEnv    = pkgs.pkgsIncludeOS.stdenv.hostPlatform;
  targetPlatform = pkgs.pkgsIncludeOS.stdenv.targetPlatform;

in

# WARN: This assert must be at the top and evaluated first,
# as an invalid target will break further evaluation.
assert assertOneOf "--argstr target <string>" "${target}" supportedTargets.name;

assert assertMsg buildPlatform.isLinux
"Currently only Linux builds are supported";

assert assertMsg compilerEnv.isMusl
"Stdenv should be based on Musl";

assert assertOneOf "crossSystem.system" targetPlatform.system supportedTargets.system;

pkgs.pkgsIncludeOS.includeos
