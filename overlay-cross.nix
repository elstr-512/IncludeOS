# ./overlay.nix

{
  # Enable ccache support. See overlay.nix for details. <- recursive explanation :p
  withCcache ? false

  # TODO: see https://github.com/NixOS/nixpkgs/issues/395191
, disableTargetWarning ? true

  # WARN:
  # None of the args listed below are used by this overlay,
  # they only exist to provide compatability with the
  # projects older *.nix files.

  # Enable multicore suport.
, smp ? false
}:

final: prev: {

  # ────────────────────────────────
  # Helper: Create stdenv with custom libc
  # .
  mkStdenvCustomLibc = { libc, stdenv }:
    let
      # STEP 1: Rebuild bintools with the custom libc.
      # .
      bintools = stdenv.cc.bintools.override { inherit libc; };
    in
      # STEP 2: Override the C compiler with
      #
      # - the new libc
      # - the new bintools
      #
      # Both the compiler and bintools are required to
      # have the same libc so linking works correctly.
      # (also nix will complain if not)
      # .
      stdenv.override {
        cc = stdenv.cc.override {
          inherit libc bintools;
        };
        # STEP 3: Add bintools to allowed requisites so it doesn't get GC'd
        #
        # AllowedRequisites are derivations the stdenv
        # is allowed to depend on. Without it, the
        # garbage collector may think they are unused and
        # remove them.
        #
        # mapNullable is used because allowedRequisites can be null.
        # .
        allowedRequisites =
          prev.lib.mapNullable
          (rs: rs ++ [ bintools ])
          (stdenv.allowedRequisites or null);
      };

  # ────────────────────────────────
  # stdenvIncludeOS
  # .
  stdenvIncludeOS = prev.lib.makeScope prev.newScope (self: {

    # Base our stdenv on musl with -> LLVM toolchain: clang, libc++
    basePkgs = prev.pkgsMusl;
    baseLLvmPkgs = self.basePkgs.llvmPackages_19;
    baseStdenv = self.baseLLvmPkgs.libcxxStdenv;

    # ────────────────────────────────
    # Musl configurations
    # .
    # Overwrite includeos stdenv libc with patched musl version.
    # .
    # Libcxx is built with un-patched musl, but they must target
    # the same musl version.

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

    # ────────────────────────────────
    # Rebuild llvm stdenv
    # .
    # i.e. [libc++ libc++abi libunwind compiler-rt] against musl-pinned

    includeos_llvm = self.baseLLvmPkgs.override (old: {
      stdenv = final.mkStdenvCustomLibc {
        libc = self.musl-pinned;
        stdenv = self.baseStdenv;
      };
    });

    # ────────────────────────────────
    # libc built against patched musl
    # .
    # Custom stdenv that uses IncludeOS musl

    includeos_stdenv = final.mkStdenvCustomLibc {
      libc = self.musl-includeos-patch;
      stdenv = self.baseStdenv;
    };

    # ────────────────────────────────
    # libraries collection
    # .

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

  # ────────────────────────────────
  # TODO: ccache scope ... don't like
  # having it inside pkgsIncludeOS
  # .

  # ────────────────────────────────
  # pkgsIncludeOS
  # .
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
      # ────────────────────────────────
      # Custom stdenv for IncludeOS
      # .
      stdenv = final.stdenvIncludeOS.includeos_stdenv;
      pkgs = final.stdenvIncludeOS.basePkgs;

      targetArch = self.stdenv.targetPlatform.uname.processor;

      # ────────────────────────────────
      # Dependencies which have to be rebuilt (or wrapped) to be compatible
      # .
      botan2 = self.callPackage ./deps/botan/default.nix { }; # fix include stuff
      libfmt = self.callPackage ./deps/libfmt/default.nix { };
      s2n-tls = self.callPackage ./deps/s2n/default.nix { };
      uzlib = self.callPackage ./deps/uzlib/default.nix { }; # not available in nix pkgs

      # WARN:
      # >:(
      # The chain loader (as in the service, not i686) depends on
      # `vmbuild`, BUT `vmbuild` should be an external package.
      # ..
      # It doesn't make sense to bundle (and build) `vmbuild` inside
      # this stdenv (aka the includeos target-platform stdenv).
      # Especially with cross compilation in mind.
      vmbuild = self.callPackage ./vmbuild.nix { };

      # ────────────────────────────────
      # IncludeOS derivation
      # .
      includeos = self.stdenv.mkDerivation (this: {
        pname = "includeos";
        version = "dev";
        enableParallelBuilding = true;

        # Disable PIE since IncludeOS is a static package
        # (silences a meaningless warning)
        hardeningDisable = [ "pie" ];

        # Print the platform configurations during build
        preConfigure = ''
        echo "PLAT.CONFIG: build=${self.stdenv.buildPlatform.config} host=${self.stdenv.hostPlatform.config} target=${self.stdenv.targetPlatform.config}"

        echo "PLAT.SYSTEM: build=${self.stdenv.buildPlatform.system} host=${self.stdenv.hostPlatform.system} target=${self.stdenv.targetPlatform.system}"

        echo "TARGET.ARCH: arch=${self.targetArch}"
        '';

        # ────────────────────────────────
        # Source files
        # .
        src = prev.lib.fileset.toSource {
          root = ./.;
          # Only include files needed by IncludeOS (not examples, docs etc)
          fileset = prev.lib.fileset.unions [
            ./src
            ./api
            ./cmake
            ./deps
            ./userspace
            ./lib
            ./CMakeLists.txt
          ];
        };

        # ────────────────────────────────
        # Build inputs
        # .

        nativeBuildInputs = [
          prev.buildPackages.cmake
          prev.buildPackages.nasm
        ] ++ prev.lib.optionals disableTargetWarning [suppressTargetWarningHook]
          ++ prev.lib.optionals withCcache [self.ccacheWrapper ccacheNoticeHook];

        buildInputs = [
          prev.pkgsStatic.http-parser
          prev.pkgsStatic.openssl
          prev.pkgsStatic.rapidjson
          self.libfmt

        ] ++ this.archBuildInputs;

        # ────────────────────────────────
        # Architecture-specific build inputs
        # .
        archBuildInputs =
          if self.targetArch == "x86_64" then
            [
              self.botan2
              self.uzlib
              self.vmbuild
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

        # ────────────────────────────────
        # Post-install: bundle runtime libs
        #.
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

        # ────────────────────────────────
        # Architecture-specific CMake flags
        # .
        archCmakeFlags =
          if self.targetArch == "i686" then
            [
              "-D ARCH=i686"
              "-D PLATFORM=nano" # currently only support nano platform on i686
            ]
          else if self.targetArch == "aarch64" then
            [
              "-D ARCH=aarch64"
              "-D CMAKE_BUILD_TYPE=Debug"
            ]
          else if self.targetArch == "x86_64" then
            [
              "-D ARCH=x86_64"
            ]
          else
            [];

        cmakeFlags = this.archCmakeFlags;


        # ────────────────────────────────
        # Passthrough
        # .

        # Make IncludeOS’s internal libc/libcxx easily accessible
        passthru.libraries = final.stdenvIncludeOS.libraries;

        # access to pkgs
        passthru.pkgs = final.stdenvIncludeOS.basePkgs;

        # access to dependencies
        passthru.deps = {
          inherit (self) botan2;
          # inherit (self) cmake; <- don't do this, get cmake from pkgs.buildPackages
          inherit (self) libfmt;
          # inherit (self) s2n-tls; <- this is fixable
          inherit (self) uzlib;
          inherit (self) vmbuild;

          chainloader = import ./chainloader.nix { inherit withCcache; };

          lest = self.callPackage ./deps/lest {};
          vmrunner = self.callPackage (builtins.fetchGit {
            url = "https://github.com/includeos/vmrunner";
          }) {};
        };

        passthru.util = {
          inherit suppressTargetWarningHook;
          inherit (self) ccacheWrapper ;
        };

        meta = {
          description = "Run your application with zero overhead";
          homepage = "https://www.includeos.org/";
          license = prev.lib.licenses.asl20;
        };
      }); # end -> includeos mkDerivation

      ccacheWrapper = prev.ccacheWrapper.override {
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

    });
}
