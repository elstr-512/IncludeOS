# ./overlay.nix
{
  withCcache, # Enable ccache. Requires correct permissions, see below.
  smp,      # Enable multicore support (SMP)
} :
final: prev: {

  stdenvIncludeOS = prev.lib.makeScope prev.newScope (self:
    let

    in {
    llvmPkgs = prev.llvmPackages_18;
    stdenv = self.llvmPkgs.libcxxStdenv; # Use this as base stdenv


    # llvmPkgsABC = pkgsStatic.llvmPackages_18;
    # stdenv = self.llvmPkgsABC.libcxxStdenv; # Use this as base stdenv

    # Import unpatched musl for building libcxx. Libcxx needs some linux headers to be passed through.
    musl-unpatched = self.callPackage ./deps/musl-unpatched/default.nix {
        linuxHeaders = prev.linuxHeaders;
      };

    # Import IncludeOS musl which will be built and linked with IncludeOS services
    musl-includeos = self.callPackage ./deps/musl/default.nix {
      };

    # Clang with unpatched musl for building libcxx
    clang_musl_unpatched_nolibcxx = self.llvmPkgs.clangNoLibcxx.override (old: {
      bintools = prev.bintools.override {
        # Disable hardening flags while we work on the build
        defaultHardeningFlags = [];
        libc = self.musl-unpatched;
      };
      libc = self.musl-unpatched;
    });

    # Libcxx which will be built with unpatched musl
    libcxx_musl_unpatched = self.llvmPkgs.libcxx.override (old: {
      stdenv = (prev.overrideCC self.llvmPkgs.libcxxStdenv self.clang_musl_unpatched_nolibcxx);
    });

    # Final stdenv, use libcxx w/unpatched musl + includeos musl as libc
    clang_musl_includeos_libcxx = self.llvmPkgs.libcxxClang.override (old: {
      bintools = prev.bintools.override {
        # Disable hardening flags while we work on the build
        defaultHardeningFlags = [];
        libc = self.musl-includeos;
      };
      libc = self.musl-includeos;
      libcxx = self.libcxx_musl_unpatched;
    });

    musl_includeos_stdenv_libcxx = (prev.overrideCC self.llvmPkgs.libcxxStdenv self.clang_musl_includeos_libcxx);

    includeos_stdenv = self.musl_includeos_stdenv_libcxx;

    libraries = {
      libc = self.musl-includeos;
      libcxx = {
        # There doesn't seem to be a single package containing both libc++ headers and libs.
        lib = "${self.libcxx_musl_unpatched}/lib";
        include = "${self.libcxx_musl_unpatched.dev}/include/c++/v1";
      };
      libunwind = self.llvmPkgs.libraries.libunwind;
      libgcc = self.llvmPkgs.compiler-rt;
    };
  });

  stdenvIosService = prev.lib.makeScope prev.newScope (self:
    let

    in {
    llvmPkgs = prev.llvmPackages_18;
    stdenv = self.llvmPkgs.libcxxStdenv; # Use this as base stdenv

    # Import unpatched musl for building libcxx. Libcxx needs some linux headers to be passed through.
    musl-unpatched = self.callPackage ./deps/musl-unpatched/default.nix {
        linuxHeaders = prev.linuxHeaders;
      };

    # Import IncludeOS musl which will be built and linked with IncludeOS services
    musl-includeos = self.callPackage ./deps/musl/default.nix {
      };

    # Clang with unpatched musl for building libcxx
    clang_musl_unpatched_nolibcxx = self.llvmPkgs.clangNoLibcxx.override (old: {
      bintools = prev.bintools.override {
        # Disable hardening flags while we work on the build
        defaultHardeningFlags = [];
        libc = self.musl-unpatched;
      };
      libc = self.musl-unpatched;
    });

    # Libcxx which will be built with unpatched musl
    libcxx_musl_unpatched = self.llvmPkgs.libcxx.override (old: {
      stdenv = (prev.overrideCC self.llvmPkgs.libcxxStdenv self.clang_musl_unpatched_nolibcxx);
    });

    # Final stdenv, use libcxx w/unpatched musl + includeos musl as libc
    clang_musl_includeos_libcxx = self.llvmPkgs.libcxxClang.override (old: {
      bintools = prev.bintools.override {
        # Disable hardening flags while we work on the build
        defaultHardeningFlags = [];
        libc = self.musl-includeos;
      };
      libc = self.musl-includeos;
      libcxx = self.libcxx_musl_unpatched;
    });

    musl_includeos_stdenv_libcxx = (prev.overrideCC self.llvmPkgs.libcxxStdenv self.clang_musl_includeos_libcxx);

    includeos_stdenv = self.musl_includeos_stdenv_libcxx;

    libraries = {
      libc = self.musl-includeos;
      libcxx = {
        # There doesn't seem to be a single package containing both libc++ headers and libs.
        lib = "${self.libcxx_musl_unpatched}/lib";
        include = "${self.libcxx_musl_unpatched.dev}/include/c++/v1";
      };
      libunwind = self.llvmPkgs.libraries.libunwind;
      libgcc = self.llvmPkgs.compiler-rt;
    };
  });

  pkgsIncludeOS = prev.lib.makeScope prev.newScope (self:
    let

    in {
    # self.callPackage will use this stdenv.
    stdenv = final.stdenvIncludeOS.includeos_stdenv;

    # Deps
    botan2 = self.callPackage ./deps/botan/default.nix { }; # fix include stuff
    s2n-tls = self.callPackage ./deps/s2n/default.nix { };
    uzlib = self.callPackage ./deps/uzlib/default.nix { };

    # IncludeOS
    includeos = self.stdenv.mkDerivation (this: {
      pname = "includeos";
      version = "dev";

      preConfigure = ''
        echo "PLAT: build=${self.stdenv.buildPlatform.config} host=${self.stdenv.hostPlatform.config} target=${self.stdenv.targetPlatform.config}"
      '';

      enableParallelBuilding = true;

      # Convenient access to libc, libcxx etc
      passthru.libraries = final.stdenvIncludeOS.libraries;

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

      nativeBuildInputs = [
        prev.buildPackages.cmake
        prev.buildPackages.nasm
      ];

      aarch64_inputs =
          if self.stdenv.targetPlatform.system == "aarch64-linux" then [
            prev.pkgsStatic.dtc
          ]
          else [];

      buildInputs = [
        self.botan2
        self.uzlib

        prev.pkgsStatic.http-parser
        prev.pkgsStatic.openssl
        prev.pkgsStatic.rapidjson

      ] ++ this.aarch64_inputs;

      postInstall = ''
        cp -r  ${final.stdenvIncludeOS.libraries.libc} $out/libc

        mkdir $out/libcxx
        cp -r  ${final.stdenvIncludeOS.libraries.libcxx.lib} $out/libcxx/lib
        cp -r  ${final.stdenvIncludeOS.libraries.libcxx.include} $out/libcxx/include
        cp -r  ${final.stdenvIncludeOS.libraries.libunwind} $out/libunwind
        cp -r  ${final.stdenvIncludeOS.libraries.libgcc} $out/libgcc

      ''
      + prev.lib.optionalString prev.stdenv.isAarch64 ''
        mkdir -p $out/dtc/lib
        cp -r  ${prev.pkgsStatic.dtc}/lib/libfdt.a $out/dtc/lib
        cp -r  ${prev.pkgsStatic.dtc}/include $out/dtc/include

      '';

      archFlags = if self.stdenv.targetPlatform.system == "i686-linux" then
        [
          "-DARCH=i686"
          "-DPLATFORM=nano" # we currently only support nano platform on i686
        ]
      else if self.stdenv.targetPlatform.system == "aarch64-linux" then
        ["-DARCH=aarch64"]
      else
        [ "-DARCH=x86_64"];

      smpFlags = if smp then [ "-DSMP=ON" ] else [];

      cmakeFlags = this.archFlags ++ this.smpFlags;

      meta = {
        description = "Run your application with zero overhead";
        homepage = "https://www.includeos.org/";
        license = prev.lib.licenses.asl20;
      };
    });
  });
}
