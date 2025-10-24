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

