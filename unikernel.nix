{
  # The unikernel to build
  unikernel ? ./example,

  # The test file to run
  test ? "test.py",

  # Boot unikernel after building it
  doCheck ? false,

  # Which architecture to build against
  arch ? "x86_64",

  # Enable multicore suport.
  smp ? false,

  # Enable ccache support. See overlay.nix for details.
  withCcache ? false,

  # Enable stricter requirements
  forProduction ? false,

  # The includeos library to build and link against
  includeos ? import ./default.nix {
    target = "${arch}";
    inherit withCcache;
    inherit smp;
  },

  # Packages for the build platform
  nixpkgs ? ./pinned.nix,
  pkgs ? import nixpkgs {},

  # vmrunner path, for vmrunner development
  vmrunner ? "",
}:
let
  absolutePathOf = base: p:
    if p == null then null else
    if builtins.isPath p then p
    else builtins.toPath (base + "/${p}");

  unikernelPath = absolutePathOf ./. unikernel;
  vmrunnerPkg =
    if vmrunner == "" then
      includeos.vmrunner
    else
      pkgs.callPackage (builtins.toPath /. + vmrunner) {};
in
includeos.stdenv.mkDerivation rec {
  pname = "includeos_example";
  version = "dev";
  src = includeos.pkgs.lib.cleanSource unikernelPath;
  dontStrip = true;
  inherit doCheck;

  nativeBuildInputs = [
    includeos.pkgs.buildPackages.nasm
    includeos.pkgs.buildPackages.cmake
  ] ++ [ includeos.util.suppressTargetWarningHook ];

  buildInputs = [
    includeos
  ];

  propagatedBuildInputs = [
    includeos.chainloader
  ];

  cmakeFlags = [
    "-DARCH=${arch}"
    "-DINCLUDEOS_PACKAGE=${includeos}"
    "-DCMAKE_MODULE_PATH=${includeos}/cmake"
    "-DFOR_PRODUCTION=${if forProduction then "ON" else "OFF"}"
  ];

  installPhase = ''
    runHook preInstall
    # we want to place any files required by the test into the output
    find -mindepth 1 -maxdepth 1 -type f -exec install -v -D -t "$out/" {} \;

    # especially the unikernel image, in case it wasn't at the rootdir already
    find -mindepth 2 -name '*.elf.bin' -exec install -v -t "$out/" {} \;
    runHook postInstall
  '';


  nativeCheckInputs = [
    includeos.vmrunner
    pkgs.grub2
    pkgs.python3
    pkgs.qemu
    pkgs.iputils
    pkgs.xorriso
  ];

  checkInputs = [
    includeos.deps.lest
  ];

  # use `nix-build --arg doCheck true` to run tests normally
  checkPhase = ''
    runHook preCheck
    set -e
    if [ -e "${src}/${test}" ]; then
      echo "Running IncludeOS test: ${src}/${test}"
      python3 "${src}/${test}"
    else
      echo "Default test script '${test}', but no test was found 😟"
      echo "For a custom path, consider specifying the path to the test script:"
      echo "    --argstr test 'path/to/test.py'"
      exit 1
    fi
    runHook postCheck
  '';

  # the doCheck shell is a hack
  # some tests need to be run through a shell because of net_cap_raw+ep and net_cap_admin+ep
  # replace nix-build with nix-shell to test without dropping capabilities
  packages = [
    (pkgs.python3.withPackages (p: [
      vmrunnerPkg
    ]))
  ];
  shellHook = if doCheck then ''
    set -eu
    pkg="$(nix-build ./unikernel.nix --arg doCheck false --arg unikernel ${unikernel})"

    testPath="$(realpath "${unikernel}/${test}")"
    cd "$pkg"
    "$testPath" || exit 1

    exit 0
  '' else ''
    echo "entering unikernel build shell."
    echo "if you want to run tests, you can do so with:"
    echo "  --arg doCheck true"
    cd result/
  '';

}
