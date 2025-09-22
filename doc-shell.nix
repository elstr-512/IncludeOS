let
    nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/archive/24.05.tar.gz";
    pkgs = (import nixpkgs {}).pkgsCross.aarch64-multiplatform;

    uzlib = pkgs.callPackage ./deps/uzlib/default.nix { };
in

# callPackage is needed due to https://github.com/NixOS/nixpkgs/pull/126844
pkgs.pkgsStatic.callPackage ({ mkShell, zlib, pkg-config, file }: mkShell {

  # these tools run on the build platform, but are configured to target the host platform
  nativeBuildInputs = with pkgs.buildPackages; [
    pkg-config
    file
    cmake
    ninja
  ];

  # libraries needed for the host platform
  # libraries compiled for the *target* platform
  buildInputs = with pkgs; [
    uzlib
    openssl
    rapidjson
    http-parser
    botan2
    s2n-tls
  ];

  # Environment helpers
  shellHook = ''
    PROJECTDIR="$(pwd)"
    BUILDPATH="$PROJECTDIR/build"
    # rm -rf "$BUILDPATH"
    mkdir -p "$BUILDPATH"
    pushd "$BUILDPATH"

    echo -e "\n- - - - The C++ compiler set to: $CXX - - - -"
    echo $(which $CXX)

    INCLUDEPATHS=""
    INCLUDEPATHS+="-I$PROJECTDIR/api "
    INCLUDEPATHS+="-I${pkgs.botan2.dev}/include/botan-2 "

    CMAKEFLAGS=""
    CMAKEFLAGS+=" -DARCH=aarch64 "

    CMAKEFLAGS+=" -DCMAKE_C_FLAGS='$INCLUDEPATHS' "
    CMAKEFLAGS+=" -DCMAKE_CXX_FLAGS='$INCLUDEPATHS' "

    CMAKEFLAGS+=" -DCMAKE_SYSTEM_NAME=Linux "
    CMAKEFLAGS+=" -DCMAKE_SYSTEM_PROCESSOR=aarch64 "

    CMAKEFLAGS+=" -DCMAKE_C_COMPILER=$CC "
    CMAKEFLAGS+=" -DCMAKE_CXX_COMPILER=$CXX "

    echo -e "\nWORK IN PROGRESS BUILD WITH THIS I GUESS:"
    echo "cmake $CMAKEFLAGS .. && cmake --build ."
  '';
}) {}

