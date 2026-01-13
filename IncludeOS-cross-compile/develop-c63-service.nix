# develop-c63-service.nix
#
# c63 encoder service
#

{
  # Path to build directory created by CMake.
  buildpath ? "build-${arch}"

  # Enable ccache support.
, withCcache ? false

  # Target platform
, arch ? "aarch64"

  # packages for the build platform
, nixpkgs ? ../pinned.nix

, pkgs ? import nixpkgs {}

  # includeos derivation
, includeos ? import ../default-cross.nix {
    target = "${arch}";
    inherit withCcache;
  }

  # packages configured for the target architecture
, crossPkgs ? includeos.pkgs

, u-boot ? import ./uboot-aarch64.nix

  # use zsh instead of bash
, useZsh ? false
}:

pkgs.mkShell.override { inherit (includeos) stdenv; } rec {

  # Build tools that run on the build platform, but are
  # configured to target the *target-architecture* platform.
  nativeBuildInputs = [
    crossPkgs.buildPackages.cmake
    crossPkgs.buildPackages.nasm
  ];

  # Tools configured to run on the build platform.
  packages = [
    pkgs.qemu
    pkgs.dtc
    pkgs.aarch64-esr-decoder
  ];

  # compiled for the *target* platform
  buildInputs = [
    includeos
    includeos.deps.libfmt
  ];

  shellHook = ''
    # Check recursive develop-shell
    if [[ "$INSIDE_DEVELOP_SHELL" ]]; then
      echo -e "Error: recursive develop-shell ... exiting"
      exit 1
    fi
    export INSIDE_DEVELOP_SHELL=1

    INCLUDEOS=${includeos}
    USE_ZSH=${toString useZsh}

    ROOT_SRC_DIR=${toString ../.}
    AARCH64_ROOT_DIR=${toString ./.}
    BUILDPATH=${buildpath}
    ARCH=${arch}

    # delete old just in case it's dirty
    [[ -d $BUILDPATH ]] && {
      rm -rf $BUILDPATH;
    }

    # build includeOS
    cmake -S $ROOT_SRC_DIR -B $BUILDPATH \
      -D CMAKE_EXPORT_COMPILE_COMMANDS=ON \
      -D ARCH=$ARCH \
      -D CMAKE_MODULE_PATH=$INCLUDEOS/cmake

    # procuced by CMake
    CCDB="$BUILDPATH/compile_commands.json"

    # attempting to use -resource-dir with 'clang++ -print-resource-dir'
    # doesn't work here as we're using -nostdlib/-nostdlibinc
    IOS_LIB_LICXX_INCLUDE=${includeos.libraries.libcxx.include}
    IOS_LIB_LIBC=${includeos.libraries.libc}

    tmp="$CCDB.clangd.tmp"
    jq \
      --arg libcxx "$IOS_LIB_LICXX_INCLUDE" \
      --arg libc "$IOS_LIB_LIBC" \
      --arg localsrc "$ROOT_SRC_DIR" \
      '
      map(.command |= ( .
          + " -isystem \($libcxx)"
          + " -isystem \($libc)/include"
          | gsub("(?<a>-I)(?<b>/lib/LiveUpdate/include)"; .a + $localsrc + .b)
      ))
    ' "$CCDB" > "$tmp" && mv "$tmp" "$CCDB"

    # most clangd configurations and editors will look in ./build/, but this just makes it easier to find for some niche edge cases
    cd $ROOT_SRC_DIR
    ln -sfn "$AARCH64_ROOT_DIR/$BUILDPATH/compile_commands.json" "$ROOT_SRC_DIR/compile_commands.json"
    cd $AARCH64_ROOT_DIR

    # build aarch64_c63_enc service
    EXAMPLE_SOURCE="aarch64_c63_enc/"

    if [[ -d $EXAMPLE_SOURCE ]]; then
      SERVICE_BUILDPATH="$BUILDPATH-example"

      [[ -d $SERVICE_BUILDPATH ]] && {
        echo "Removing dirty 'example build' directory...";
        rm -rf $SERVICE_BUILDPATH;
      }

      [[ ! -d $SERVICE_BUILDPATH ]] && {
        cmake -S $EXAMPLE_SOURCE -B $SERVICE_BUILDPATH -D ARCH=$ARCH -D CMAKE_BUILD_TYPE=Debug 2>&1
        (cd $SERVICE_BUILDPATH && make -j 2 2>&1)

        if [ $? -ne 0 ]; then # service build error
          exit
        fi
      }
    fi


    # Create dir with services/tools for booting (aarch64) includeos
    [[ ! -d boot ]] && {
      mkdir -p boot
    }

    SERVICE_RESULT="$SERVICE_BUILDPATH/hello_includeos.elf.bin"

    U_BOOT=${u-boot}

    if [[ -e $SERVICE_RESULT ]]; then
      cp -f $SERVICE_RESULT boot/
      cp -f $U_BOOT/u-boot.bin boot/

      # insert correct project root for gdb
      sed -i "/^PROJECT_ROOT    :=.*/c\PROJECT_ROOT    := $ROOT_SRC_DIR" boot/Makefile
      cd boot
    fi

    # optional use zsh
    if [[ $USE_ZSH ]]; then
      exec zsh
    fi
  '';
}

