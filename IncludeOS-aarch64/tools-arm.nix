# tools-arm.nix
#
# Sets up a development shell with necessary tools
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

, useZsh ? true
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
    [[ -d ${buildpath} ]] && {
      rm -rf buildpath;
    }

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


    echo "" # booting with qemu :p
    echo "- - - - ~ in boot/ dir ~ - - - -"
    echo "boot kernel directly (not recommended, u-boot handles initialization better):"
    echo -e "qemu-system-aarch64 -machine virt -cpu cortex-a57 -kernel hello_includeos.elf.bin -nographic \n"

    echo "boot u-boot:"
    echo "objdump -dC hello_includeos.elf.bin | grep \"<_start>\""
    echo "qemu-system-aarch64 -machine virt -cpu cortex-a57 -bios u-boot.bin -device loader,file=hello_includeos.elf.bin,addr=0x40200000 -nographic"
    echo -e "in u-boot bios => go 0x402~>(whatever <_start> is) \n"

    # optional zsh
    if [[ -z "$INSIDE_ZSH" && "${toString useZsh}" ]]; then
      export INSIDE_ZSH=1
      exec zsh
    fi
  '';
}

