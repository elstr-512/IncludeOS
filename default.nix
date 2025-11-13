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
    crossSystem = {
      config = "x86_64-unknown-linux-musl";
      # config = "aarch64-unknown-linux-musl";
    };
  }
}:

let
  supportedTargets.system = [
    "x86_64-linux"
    "i686-linux"
    "aarch64-linux"
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
