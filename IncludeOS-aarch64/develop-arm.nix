# develop-arm.nix
#
# Sets up a development shell in which you can open your editor
#

{
  # Path to build directory created by CMake.
  buildpath ? "build-${arch}"

  # Enable ccache support. See overlay.nix for details.
, withCcache ? true

  # Enable multicore suport.
, smp ? false

  # Target platform
, arch ? "aarch64"

, nixpkgs ? ../pinned.nix

  # packages for the build platform
, pkgs ? import nixpkgs {}

, includeos ? import ./default.nix { inherit withCcache smp; }

  # packages configured for the target architecture (arch)
, crossPkgs ? includeos.pkgs

, u-boot ? import ./uboot-aarch64.nix

  # use zsh instead of bash
, useZsh ? false

  # dont build, just get a shell with handy tools
, skipBuild ? false
}:

pkgs.mkShell.override { inherit (includeos) stdenv; } rec {

  nativeBuildInputs = [
    /* NOTE:
     * Build tools that run on the build platform, but are
     * configured to target the *target-architecture* platform.
     */
    crossPkgs.buildPackages.cmake
    crossPkgs.buildPackages.nasm

    /* NOTE:
     * Tools configured to run on the build platform.
     */
    pkgs.qemu
    pkgs.dtc
  ];

  # compiled for the *target* platform
  buildInputs = [
    includeos
  ];

  shellHook = ''
    # Check recursive develop-shell
    if [[ "$INSIDE_DEVELOP_SHELL" ]]; then
      echo -e "Error: recursive develop-shell ... exiting"
      exit 1
    fi
    export INSIDE_DEVELOP_SHELL=1

    INCLUDEOS=${includeos}
    SKIP_BUILD=${toString skipBuild}
    USE_ZSH=${toString useZsh}
    if [[ $SKIP_BUILD ]]; then
      # optional zsh
      echo $INCLUDEOS
      if [[ -z $INSIDE_ZSH && $USE_ZSH ]]; then
        export INSIDE_ZSH=1
        exec zsh
      fi

      return 0
    fi

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
    ln -sfn "$BUILDPATH/compile_commands.json" "$AARCH64_ROOT_DIR/compile_commands.json"

    # build example service
    LOGFILE=$ARCH-servicebuild.log
    nix log $INCLUDEOS > $LOGFILE
    if [[ -d example ]]; then
      cd example

      [[ -d $BUILDPATH ]] && {
        echo "Removing dirty 'example build' directory...";
        rm -rf $BUILDPATH;
      }

      [[ ! -d $BUILDPATH ]] && {
        cmake -B $BUILDPATH -D ARCH=$ARCH -D CMAKE_BUILD_TYPE=Debug 2>&1 | tee -a $LOGFILE
        (cd $BUILDPATH && make -j 2 2>&1 | tee -a $LOGFILE)

        if [ $? -ne 0 ]; then
          exit
        fi
      }

      cd $AARCH64_ROOT_DIR
    fi


    # Create dir with services/tools for booting (aarch64) includeos
    [[ ! -d boot ]] && {
      mkdir -p boot
    }

    SERVICE_RESULT="example/$BUILDPATH/hello_includeos.elf.bin"

    U_BOOT=${u-boot}

    if [[ -e $SERVICE_RESULT ]]; then
      cp -f $SERVICE_RESULT boot/
      cp -f $U_BOOT/u-boot.bin boot/
    fi

    # optional zsh
    if [[ -z $INSIDE_ZSH && $USE_ZSH ]]; then
      export INSIDE_ZSH=1
      exec zsh
    fi
  '';
}

