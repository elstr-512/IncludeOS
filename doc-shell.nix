let
    nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/archive/24.05.tar.gz";
  pkgs = (import nixpkgs {}).pkgsCross.aarch64-multiplatform;
in

# callPackage is needed due to https://github.com/NixOS/nixpkgs/pull/126844
pkgs.pkgsStatic.callPackage ({ mkShell, zlib, pkg-config, file }: mkShell {
  # these tools run on the build platform, but are configured to target the host platform
  nativeBuildInputs = [ pkg-config file ];
  # libraries needed for the host platform
  buildInputs = [ zlib ];

  # Environment helpers
  shellHook = ''
    export BUILDPATH="build"
    mkdir -p "$BUILDPATH"
    pushd "$BUILDPATH"

    echo -e "\n- - - - The C++ compiler set to: $CXX - - - -"
    echo $(which $CXX)
    echo "rm -rf * ; cmake -DARCH=aarch64 .. ; cmake --build ."
  '';
}) {}

