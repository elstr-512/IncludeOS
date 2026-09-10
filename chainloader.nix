{
  # Enable ccache. Requires /nix/var/cache/ccache to exist with correct permissions.
  withCcache ? false,

  nixpkgs ? ./pinned.nix,

  arch ? "i686",

  includeos ? import ./default.nix {
    target = "${arch}";
    inherit withCcache;
    smp = false; # No SMP for chainloader
  },
}:
let
  pkgs   = includeos.pkgs;
  stdenv = includeos.stdenv;

  assertMsg      = pkgs.lib.asserts.assertMsg;
  assertOneOf    = pkgs.lib.asserts.assertOneOf;

  compilerEnv    = stdenv.hostPlatform;
  targetPlatform = stdenv.targetPlatform;
in

assert assertMsg (targetPlatform.system == "i686-linux")
"Chainloader must be built as 32-bit target";

assert assertMsg targetPlatform.isLinux
"Target platform must be Linux";

assert assertMsg compilerEnv.isMusl
"Stdenv should be based on Musl";

stdenv.mkDerivation rec {
  pname = "chainloader";
  version = "dev";

  sourceRoot = "./src/chainload/";

  buildInputs = [
    includeos
  ];

  srcs = [
    ./src
    ./api
    ./cmake
    ];

  nativeBuildInputs = [
    pkgs.buildPackages.cmake
    pkgs.buildPackages.nasm
  ] ++ [ includeos.util.suppressTargetWarningHook ];
}
