{
  # Will create a temp one if none is passed, for example:
  # nix-shell --argstr buildpath .
  buildpath ? "",

  # The unikernel to build
  unikernel ? "./example",

  # vmrunner path, for vmrunner development
  vmrunner ? "",

  # Enable ccache support. See overlay.nix for details.
  withCcache ? false,

  # Enable multicore suport.
  smp ? false,

  includeos ? import ./default.nix { inherit withCcache; inherit smp; }

}:

includeos.pkgs.mkShell.override { inherit (includeos) stdenv; } rec {
  vmrunnerPkg =
    if vmrunner == "" then
      includeos.vmrunner
    else
      includeos.pkgs.callPackage (builtins.toPath /. + vmrunner) {};

  packages = [
    (includeos.pkgs.python3.withPackages (p: [
      vmrunnerPkg
    ]))
    includeos.pkgs.buildPackages.cmake
    includeos.pkgs.buildPackages.nasm
    includeos.pkgs.qemu
    includeos.pkgs.which
    includeos.pkgs.grub2
    includeos.pkgs.iputils
    includeos.pkgs.xorriso
  ];

  buildInputs = [
    includeos
    includeos.chainloader
    includeos.lest
    includeos.pkgs.openssl
    includeos.pkgs.rapidjson
  ];

  # Environment helpers
  shellHook = ''
    export BUILDPATH="build"
    mkdir -p "$BUILDPATH"
    pushd "$BUILDPATH"

    echo -e "\n- - - - The C++ compiler set to: $CXX - - - -"
    echo $(which $CXX)
    echo "rm -rf * ; cmake -DARCH=x86_64 .. ; cmake --build ."
  '';

  # shellHook = ''
  #   cmake "$unikernel" -DARCH=x86_64 -DINCLUDEOS_PACKAGE=${includeos} \
  #   -DCMAKE_MODULE_PATH=${includeos}/cmake -DFOR_PRODUCTION=OFF
  # '';
}
