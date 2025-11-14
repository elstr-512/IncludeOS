# ./overlay.nix

{
  # WARN:
  # None of the args listed below are used by this overlay,
  # they only exist to provide compatability with the
  # projects older *.nix files.

  # Enable ccache support. See overlay.nix for details.
  withCcache ? false

  # Enable multicore suport.
, smp ? false
}:

final: prev: {

  # ────────────────────────────────
  # Helper: Create stdenv with custom libc
  # .
  mkStdenvCustomLibc = { libc, stdenv ? prev.stdenv }:
    let
      # Override bintools so linking uses the given libc
      bintools = stdenv.cc.bintools.override { inherit libc; };
    in
      stdenv.override {
        cc = stdenv.cc.override {
          inherit libc bintools;
          extraPackages = [ ]; # can extend this if needed
        };
        # Add bintools to allowed requisites so it doesn't get GC'd
        allowedRequisites =
          prev.lib.mapNullable
          (rs: rs ++ [ bintools ])
          (stdenv.allowedRequisites or null);
      };

  # ────────────────────────────────
  # IncludeOS scope
  # .
  stdenvIncludeOS = prev.lib.makeScope prev.newScope (self: {

    # Base our stdenv on musl with -> LLVM toolchain: clang, libc++
    basePkgs = prev.pkgsMusl;
    baseLLvmPkgs = self.basePkgs.llvmPackages_18;
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
    # stdenvIncludeOS - libraries collection
    # .

    libraries = {
      # libc built against patched musl
      libc = self.includeos_stdenv.cc.libc;

      # everything else built against pinned-musl
      libcxx = self.includeos_llvm.libcxx.overrideAttrs {
        lib = "${self.includeos_llvm.libcxx}/lib";
        include = "${self.includeos_llvm.libcxx.dev}/include/c++/v1";
      };
      libunwind = self.includeos_llvm.libraries.libunwind;
      libgcc = self.includeos_llvm.compiler-rt;
    };
  });

  # ────────────────────────────────
  # Package scope: pkgsIncludeOS
  # .
  pkgsIncludeOS = prev.lib.makeScope prev.newScope (self:
    let

    in {
      # ────────────────────────────────
      # Custom stdenv for IncludeOS
      # .
      stdenv = final.stdenvIncludeOS.includeos_stdenv;

      targetArch = self.stdenv.targetPlatform.uname.processor;

      # ────────────────────────────────
      # Dependencies which have to be rebuilt (or wrapped) to be compatible
      # .
      botan2 = self.callPackage ./deps/botan/default.nix { }; # fix include stuff
      s2n-tls = self.callPackage ./deps/s2n/default.nix { };
      uzlib = self.callPackage ./deps/uzlib/default.nix { };

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
      #
      # TODO:
      # - Figure out if runtime libs should come from:
      #   - <prev.pkgsStatic>
      #   - or
      #   - something in <stdenvIncludeOS>, maybe (basePkgs)
      # .
      includeos = self.stdenv.mkDerivation (this: {
        pname = "includeos";
        version = "dev";
        enableParallelBuilding = true;

        # Make IncludeOS’s internal libc/libcxx easily accessible
        passthru.libraries = final.stdenvIncludeOS.libraries;

        # Disable PIE since IncludeOS is a static package
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
        ];

        buildInputs = [
          prev.pkgsStatic.zlib
          prev.pkgsStatic.http-parser
          prev.pkgsStatic.openssl
          prev.pkgsStatic.rapidjson

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

        ''
        + prev.lib.optionalString (self.targetArch == "x86_64") ''
        mkdir -p "$out/tools/vmbuild"
        cp -v ${self.vmbuild}/bin/* "$out/tools/vmbuild"

        ''
        + prev.lib.optionalString (self.targetArch == "aarch64") ''
        mkdir -p $out/dtc/lib
        cp -r  ${prev.pkgsStatic.dtc}/lib/libfdt.a $out/dtc/lib
        cp -r  ${prev.pkgsStatic.dtc}/include $out/dtc/include

        ''
        + prev.lib.optionalString (self.targetArch == "i686") ''
        mkdir -p "$out/tools/vmbuild"
        cp -v ${self.vmbuild}/bin/* "$out/tools/vmbuild"

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
            ]
          else if self.targetArch == "x86_64" then
            [
              "-D ARCH=x86_64"
            ]
          else
            [];

        cmakeFlags = this.archCmakeFlags;

        meta = {
          description = "Run your application with zero overhead";
          homepage = "https://www.includeos.org/";
          license = prev.lib.licenses.asl20;
        };
      });
    });
}
