# develop-arm.nix
#
# Sets up a development shell in which you can open your editor
#

{
  # Path to build directory created by CMake.
  buildpath ? "build-${arch}"

  # Path to your unikernel source. (project root with CMakeLists.txt)
, unikernel ? "../."

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

, useZsh ? false
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
  ];

  # compiled for the *target* platform
  buildInputs = [
    includeos
  ];

  shellHook = ''
    IOS_SRC=${toString ../.}
    IOS_AARCH64_DIR=${toString ./.}

    if [ ! -d "$IOS_SRC" ]; then
        echo "$unikernel is not a valid directory" >&2
        return 1
    fi

    echo "Configuring in: ${buildpath}"
    echo "Source tree: $IOS_SRC"

    # delete old just in case it's dirty
    # [[ -d ${buildpath} ]] && {
    #   rm -rf buildpath;
    # }
    # mkdir -p ${buildpath}

    # build includeOS
    cmake -S "$IOS_SRC" -B ${buildpath} \
      -D CMAKE_EXPORT_COMPILE_COMMANDS=ON \
      -D ARCH=${arch} \
      -D CMAKE_MODULE_PATH=${includeos}/cmake

    # procuced by CMake
    CCDB="${buildpath}/compile_commands.json"

    #
    # attempting to use -resource-dir with 'clang++ -print-resource-dir'
    # doesn't work here as we're using -nostdlib/-nostdlibinc
    #
    tmp="$CCDB.clangd.tmp"
    jq \
      --arg libcxx "${includeos.libraries.libcxx.include}" \
      --arg libc "${includeos.libraries.libc}"             \
      --arg localsrc "${toString ./.}"                           \
      '
      map(.command |= ( .
          + " -isystem \($libcxx)"
          + " -isystem \($libc)/include"
          | gsub("(?<a>-I)(?<b>/lib/LiveUpdate/include)"; .a + $localsrc + .b)
      ))
    ' "$CCDB" > "$tmp" && mv "$tmp" "$CCDB"

    # most clangd configurations and editors will look in ./build/, but this just makes it easier to find for some niche edge cases
    ln -sfn "${buildpath}/compile_commands.json" "$IOS_AARCH64_DIR/compile_commands.json"

    # build example service
    if [[ -d example ]]; then
      cd example

      LOGFILE=$(pwd)/${arch}-servicebuild.log
      nix log "${includeos}" > "$LOGFILE"

      # [[ -d ${buildpath} ]] && {
      #   echo "Removing dirty 'example build' directory...";
      #   rm -rf "${buildpath}";
      # }

      [[ ! -d ${buildpath} ]] && {
        cmake -B ${buildpath} -D ARCH="${arch}" 2>&1 | tee -a "$LOGFILE"
        (cd ${buildpath} && make 2>&1 | tee -a "$LOGFILE")
      }

      # echo -e "\n grep DEBUG $LOGFILE:"
      # grep DEBUG "$LOGFILE"

      # echo -e "\n grep x86 $LOGFILE:"
      # grep x86 "$LOGFILE"

      # echo -e "\n nm -C platform/libaarch64_default.a | grep fdt"
      # nm -C ${includeos}/platform/libaarch64_default.a | grep fdt

      echo -e "\n aarch64 result (nix derivation) ->"
      echo -e "${includeos}\n"

      echo -e "\n rebuild ->"
      echo -e "cmake -B ${buildpath} -D ARCH="${arch}" && (cd ${buildpath}; make)"

      echo -e "\n"

      cd $IOS_AARCH64_DIR
    fi


    # Create dir for booting (aarch64) includeos
    [[ -d boot ]] && {
      rm -rf boot;
    }
    mkdir -p boot

    IOS_SERVICE="example/${buildpath}/hello_includeos.elf.bin"

    if [[ -e $IOS_SERVICE ]]; then
      cp -v $IOS_SERVICE boot/
      cp -v ${u-boot}/u-boot.bin boot/
    fi

    # optional zsh
    if [[ -z "$INSIDE_ZSH" && "${toString useZsh}" ]]; then
      export INSIDE_ZSH=1
      exec zsh
    fi
  '';
}

