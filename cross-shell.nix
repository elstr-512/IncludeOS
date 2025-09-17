let
  # Pin a stable nixpkgs release
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/archive/24.05.tar.gz";

  # Normal (native) pkgs
  pkgs = import nixpkgs {};

  # Cross toolchain for aarch64 Linux
  cross = pkgs.pkgsCross.aarch64-multiplatform;
  # cross = pkgs.pkgsCross.aarch64-multiplatform-musl;
in

pkgs.mkShell.override
{
  stdenv = pkgs.clangStdenv;
}
{
  # Tools you run on your own machine (build platform)
  nativeBuildInputs = with pkgs; [
    cmake
    nasm
    musl
  ];

  # Libraries compiled for the *target* platform
  buildInputs = with cross; [
    zlib
    openssl
    rapidjson
    http-parser
    botan2
  ];

  # Environment helpers
  shellHook = ''
    export BUILDPATH="build"
    mkdir -p "$BUILDPATH"
    pushd "$BUILDPATH"

    echo -e "\n- - - - The C++ compiler set to: $CXX - - - -"
    echo $(which $CXX)
    echo "rm -rf * ; cmake -DARCH=aarch64 .. ; cmake --build ."
  '';
}

