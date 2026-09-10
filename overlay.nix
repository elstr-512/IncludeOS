{
  # Access to build-platform packages.
  nixpkgs ? ./pinned.nix,
  defaultNixpkgs ? import nixpkgs {},

  # Enable ccache.
  # Requires correct permissions, see 'ccacheNoticeHook' 'ccacheWrapper' below.
  withCcache ? false,

  # TODO: see https://github.com/NixOS/nixpkgs/issues/395191
  disableTargetWarning ? true,

  # Enable multicore suport (SMP).
  # WARN:
  # While the SMP flag exists in the nix-config,
  # it is currently always defined as ON in CMakelists.txt
  smp ? false,
} :
final: prev: {
  # Create stdenv with provided libc
  mkStdenvCustomLibc = { libc, stdenv }:
    let
      # Rebuild bintools with new libc.
      bintools = stdenv.cc.bintools.override { inherit libc; };
    in
      # Override the compiler with
      # - the new libc
      # - the new bintools
      #
      # Compiler and bintools are required to have the same libc.
      stdenv.override {
        cc = stdenv.cc.override {
          inherit libc bintools;
        };
      };

  # Build environment for InlcudeOS
  stdenvIncludeOS = prev.lib.makeScope prev.newScope (self: {
    # Base our stdenv on musl with -> LLVM toolchain: clang, libc++
    basePkgs = prev.pkgsMusl;
    baseLLvmPkgs = self.basePkgs.llvmPackages_20;
    baseStdenv = self.baseLLvmPkgs.libcxxStdenv;

    # Musl configurations
    # - Overwrite includeos stdenv libc with patched musl version.
    # - Libcxx is built with un-patched musl, but they must target
    #   the same musl version.

    # Unpatched musl, used for building llvm stdenv
    musl-pinned = self.callPackage ./deps/musl-unpatched/default.nix {
      stdenv = self.baseStdenv;
      pkgs = self.basePkgs;
      linuxHeaders = self.basePkgs.linuxHeaders;
    };

    # IncludeOS-patched musl for the final stdenv
    musl-includeos-patch = self.callPackage ./deps/musl/default.nix {
      stdenv = self.baseStdenv;
      pkgs = self.basePkgs;
    };

    # Rebuild llvm stdenv against musl-pinned
    includeos_llvm = self.baseLLvmPkgs.override {
      stdenv = final.mkStdenvCustomLibc {
        libc = self.musl-pinned;
        stdenv = self.baseStdenv;
      };
    };

    # IncludeOS stdenv that uses IncludeOS-musl, libc built against patched musl
    includeos_stdenv = final.mkStdenvCustomLibc {
      libc = self.musl-includeos-patch;
      stdenv = self.baseStdenv;
    };

    # Libraries collection
    libraries = {
      # libc built against patched musl
      libc = self.includeos_stdenv.cc.libc;

      # everything else built against pinned-musl
      libcxx = {
        lib = "${self.includeos_llvm.libcxx}/lib";
        include = "${self.includeos_llvm.libcxx.dev}/include/c++/v1";
      };
      libunwind = self.includeos_llvm.libraries.libunwind;
      libgcc = self.includeos_llvm.compiler-rt;
    };
  });

  pkgsIncludeOS = prev.lib.makeScope prev.newScope (self:
    let
      ccacheNoticeHook = prev.writeTextFile {
        name = "ccache-notice-hook";
        destination = "/nix-support/setup-hook";
        text = ''
          echo "====="
          echo "ccache is enabled!"
          echo "If you run into any issues, try: --arg withCcache false"
          echo "It's recommended to run tests with ccache disabled to avoid cache incoherencies."
          echo "====="
        '';
      };

      suppressTargetWarningHook = prev.writeTextFile {
        name = "suppress-target-warning-hook";
        destination = "/nix-support/setup-hook";
        text = ''
          # see https://github.com/NixOS/nixpkgs/issues/395191
          # delete this hook and downstream references once resolved

          export NIX_CC_WRAPPER_SUPPRESS_TARGET_WARNING=1
        '';
      };
    in {
    # self.callPackage will use this stdenv.
    stdenv = final.stdenvIncludeOS.includeos_stdenv;
    inherit suppressTargetWarningHook;

    # Access to stdenv pkgs
    pkgs = final.stdenvIncludeOS.basePkgs;

    # Architecture to build against
    targetArch = self.stdenv.targetPlatform.uname.processor;

    # Dependencies which have to be rebuilt (or wrapped) to be compatible
    botan2 = self.callPackage ./deps/botan/default.nix { };
    libfmt = self.callPackage ./deps/libfmt/default.nix { };
    uzlib = self.callPackage ./deps/uzlib/default.nix { }; # not available in nix pkgs
    lest = self.callPackage ./deps/lest { };

    # The chain loader (as in the service, not i686) depends on 'vmbuild'
    # Has to be built for the build-platform (default environment)
    # WARN:
    # 'vmbuild' SHOULD be an external package, since it's a build-tool >:(
    vmbuild = defaultNixpkgs.callPackage ./vmbuild.nix { };

    # The x86_64 (64-bit) version of IncludeOS depends on the
    # chainloader to boot on QEMU
    chainloader = import ./chainloader.nix { inherit withCcache; };

    ccacheWrapper = prev.buildPackages.ccacheWrapper.override {
        inherit (self.stdenv) cc;
        extraConfig = ''
          export CCACHE_DIR="/nix/var/cache/ccache"
          if [ ! -d "$CCACHE_DIR" ]; then
            echo "====="
            echo "Directory '$CCACHE_DIR' does not exist"
            echo "Please create it with:"
            echo "  sudo mkdir -m0770 '$CCACHE_DIR'"
            echo "  sudo chown root:nixbld '$CCACHE_DIR'"
            echo ""
            echo 'Alternatively, disable ccache with `--arg withCcache false`'
            echo "====="
            exit 1
          fi
          if [ ! -w "$CCACHE_DIR" ]; then
            echo "====="
            echo "Directory '$CCACHE_DIR' exists, but is not accessible for user $(whoami)"
            echo "Please verify its access permissions"
            echo 'Alternatively, disable ccache with `--arg withCcache false`'
            echo "====="
            exit 1
          fi

          export CCACHE_COMPRESS=1
          export CCACHE_UMASK=007
          export CCACHE_SLOPPINESS=random_seed
        '';
      };

    # IncludeOS
    includeos = self.stdenv.mkDerivation rec {
      enableParallelBuilding = true;
      pname = "includeos";

      version = "dev";


      src = prev.lib.fileset.toSource {
          root = ./.;
          # Only include files needed by IncludeOS (not examples, docs etc)
          fileset = prev.pkgsStatic.lib.fileset.unions [
            ./src
            ./api
            ./cmake
            ./deps
            ./userspace
            ./lib
            ./CMakeLists.txt
          ];
      };

      # If you need to patch, this is the place
      postPatch = '''';

      nativeBuildInputs = [
        prev.buildPackages.cmake
        prev.buildPackages.nasm
      ] ++ prev.lib.optionals disableTargetWarning [suppressTargetWarningHook]
        ++ prev.lib.optionals withCcache [self.ccacheWrapper ccacheNoticeHook];

      buildInputs = [
        prev.pkgsStatic.http-parser
        prev.pkgsStatic.openssl
        prev.pkgsStatic.rapidjson
        #self.s2n-tls          👈 This is postponed until we can fix the s2n build.
        self.libfmt
        self.lest
      ] ++ archBuildInputs;


      # Propagate build-dependencies since IncludeOS is a library-OS
      propagatedBuildInputs = buildInputs;

      # Architecture-specific build inputs
      archBuildInputs =
        if self.targetArch == "x86_64" then
          [
            self.botan2
            self.uzlib
            self.vmbuild
            self.chainloader
          ]
        else if self.targetArch == "i686" then
          [
            self.vmbuild
          ]
        else if self.targetArch == "aarch64" then
          [
            self.botan2
            prev.pkgsStatic.dtc
          ]
        else [];


      postInstall = ''
      cp -r  ${final.stdenvIncludeOS.libraries.libc} $out/libc

      mkdir $out/libcxx
      cp -r  ${final.stdenvIncludeOS.libraries.libcxx.lib} $out/libcxx/lib
      cp -r  ${final.stdenvIncludeOS.libraries.libcxx.include} $out/libcxx/include
      cp -r  ${final.stdenvIncludeOS.libraries.libunwind} $out/libunwind
      cp -r  ${final.stdenvIncludeOS.libraries.libgcc} $out/libgcc

      cp -r  ${final.pkgsStatic.http-parser} $out/http-parser

      ''
      + prev.lib.optionalString (self.targetArch == "x86_64") ''
      mkdir -p "$out/tools/vmbuild"
      cp -v ${self.vmbuild}/bin/* "$out/tools/vmbuild"

      ''
      + prev.lib.optionalString (self.targetArch == "i686") ''
      mkdir -p "$out/tools/vmbuild"
      cp -v ${self.vmbuild}/bin/* "$out/tools/vmbuild"

      ''
      + prev.lib.optionalString (self.targetArch == "aarch64") ''
      mkdir -p $out/dtc/lib
      cp -r  ${prev.pkgsStatic.dtc}/lib/libfdt.a $out/dtc/lib
      cp -r  ${prev.pkgsStatic.dtc}/include $out/dtc/include

      '';

      # Architecture-specific CMake flags
      archFlags =
        if self.targetArch == "i686" then
          [
            "-D ARCH=i686"
            "-D PLATFORM=nano" # currently only support nano platform on i686
          ]
        else if self.targetArch == "x86_64" then
          [
            "-D ARCH=x86_64"
          ]
       else if self.targetArch == "aarch64" then
         [
           "-D ARCH=aarch64"
         ]
        else
          [];

      smpFlags = if smp then [ "-DSMP=ON" ] else [];

      cmakeFlags = archFlags ++ smpFlags;

      # Add some pasthroughs, for easily building the dependencies (for debugging):
      # $ nix-build -A NAME

      # Access to vmrunner. The tool runs on the build platform,
      # and is therefore accessed through defaultNixpkgs.
      passthru.vmrunner = defaultNixpkgs.callPackage (builtins.fetchGit {
          url = "https://github.com/includeos/vmrunner";
        }) {};

      # Access to chainloader
      passthru.chainloader = self.chainloader;

      # Convenient access to libc, libcxx etc
      passthru.libraries = final.stdenvIncludeOS.libraries;

      # Cross-build access to pkgs configured for the InlcudeOS-host
      passthru.pkgs = self.pkgs;

      # Access to IncludeOS dependencies
      passthru.deps = {
        inherit (self) uzlib;
        inherit (self) botan2;
        inherit (self) libfmt;
        #inherit (self) s2n-tls;
        inherit (self) vmbuild;
        inherit (self) lest;
      };

      passthru.util = {
        inherit suppressTargetWarningHook;
        inherit (self) ccacheWrapper ;
      };

      meta = {
        description = "Run your application with zero overhead";
        homepage = "https://www.includeos.org/";
        license = prev.pkgsStatic.lib.licenses.asl20;
      };
    };
  });
}
