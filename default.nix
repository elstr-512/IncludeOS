# ./default.nix
{
  nixpkgs ? ./pinned.nix

, overlays ? [
    ( import ./overlay.nix {} )
  ]

 # default target, can also be passed via command line: --argstr target <string>
, target ? "x86_64"

}:

let
  targets = {
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
  pkgs = targets.${target};

  # assert helpers
  supportedTargets.system = [
    "x86_64-linux"
    "aarch64-linux"
    "i686-linux"
  ];

  assertMsg      = pkgs.lib.asserts.assertMsg;
  assertOneOf    = pkgs.lib.asserts.assertOneOf;
  buildPlatform  = pkgs.pkgsIncludeOS.stdenv.buildPlatform;
  compilerEnv    = pkgs.pkgsIncludeOS.stdenv.hostPlatform;
  targetPlatform = pkgs.pkgsIncludeOS.stdenv.targetPlatform;

in

assert assertMsg buildPlatform.isLinux
"Currently only Linux builds are supported";

assert assertMsg compilerEnv.isMusl
"Stdenv should be based on Musl";

assert assertOneOf "crossSystem.system" targetPlatform.system supportedTargets.system;

pkgs.pkgsIncludeOS.includeos
