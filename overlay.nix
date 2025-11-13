# ./overlay.nix

{}:
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
    llvmPkgs = self.basePkgs.llvmPackages_18;
    baseStdenv = self.llvmPkgs.libcxxStdenv;

    # ────────────────────────────────
    # Musl configurations, overwrite stdenv libc with pinned musl version
    # .

    # Unpatched musl, used for building (musl) libcxx
    musl-unpatched = self.callPackage ./deps/musl-unpatched/default.nix {
      stdenv = self.baseStdenv;
      pkgs = self.basePkgs;
      linuxHeaders = self.basePkgs.linuxHeaders;
    };

    # IncludeOS-patched musl for the final stdenv
    musl-includeos = self.callPackage ./deps/musl/default.nix {
      stdenv = self.baseStdenv;
      pkgs = self.basePkgs;
    };

    # Custom stdenv that uses IncludeOS musl
    includeos_stdenv = final.mkStdenvCustomLibc {
      libc = self.musl-includeos;
      stdenv = self.baseStdenv;
    };

    # ────────────────────────────────
    # libc++ built against musl-unpatched
    # .

    # Rebuild libc++ and libc++abi against a musl-based stdenv
    libcxx-musl = prev.llvmPackages_18.libcxx.override {
      stdenv = final.mkStdenvCustomLibc {
        libc = self.musl-unpatched;
        stdenv = self.baseStdenv;
      };
    };
    libcxxabi-musl = prev.llvmPackages_18.libcxxabi.override {
      stdenv = final.mkStdenvCustomLibc {
        libc = self.musl-unpatched;
        stdenv = self.baseStdenv;
      };
    };

    # ────────────────────────────────
    # stdenvIncludeOS - libraries collection
    #
    libraries = {
      libc = self.musl-includeos;
      libcxx = {
        lib = "${self.libcxx-musl}/lib";
        include = "${self.libcxx-musl.dev}/include/c++/v1";
      };
      libunwind = self.llvmPkgs.libraries.libunwind;
      libgcc = self.llvmPkgs.compiler-rt;
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
      # NOTE: Everything inside here builds in the
      #       musl-based-stdenv IncludeOS environment
      stdenv = final.stdenvIncludeOS.includeos_stdenv;

      # ────────────────────────────────
      # Dependencies which have to be rebuilt (or wrapped) to be compatible
      # .
      botan2 = self.callPackage ./deps/botan/default.nix { }; # fix include stuff
      s2n-tls = self.callPackage ./deps/s2n/default.nix { };
      uzlib = self.callPackage ./deps/uzlib/default.nix { };

      # ────────────────────────────────
      # IncludeOS derivation
      # .
      includeos = self.stdenv.mkDerivation (this: {
        pname = "includeos";
        version = "dev";
        enableParallelBuilding = true;

        # Make IncludeOS’s internal libc/libcxx easily accessible
        passthru.libraries = final.stdenvIncludeOS.libraries;

        # (mini) HACK: Disable PIE since IncludeOS is a static package
        hardeningDisable = [ "pie" ];

        # Print the platform configurations during build
        preConfigure = ''
        echo "PLAT.CONFIG: build=${self.stdenv.buildPlatform.config} host=${self.stdenv.hostPlatform.config} target=${self.stdenv.targetPlatform.config}"
        echo "PLAT.SYSTEM: build=${self.stdenv.buildPlatform.system} host=${self.stdenv.hostPlatform.system} target=${self.stdenv.targetPlatform.system}"
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
          self.botan2

          prev.pkgsStatic.zlib
          prev.pkgsStatic.http-parser
          prev.pkgsStatic.openssl
          prev.pkgsStatic.rapidjson

        ] ++ this.aarch64_inputs ++ this.x86_64_inputs;

        # Additional inputs depending on platform
        x86_64_inputs =
          if self.stdenv.targetPlatform.system == "x86_64-linux" then
            [
              self.uzlib
            ]
          else [];

        aarch64_inputs =
          if self.stdenv.targetPlatform.system == "aarch64-linux" then
            [
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
          + prev.lib.optionalString prev.stdenv.isAarch64 ''
        mkdir -p $out/dtc/lib
        cp -r  ${prev.pkgsStatic.dtc}/lib/libfdt.a $out/dtc/lib
        cp -r  ${prev.pkgsStatic.dtc}/include $out/dtc/include

          '';

        # ────────────────────────────────
        # Architecture-specific CMake flags
        # .
        archFlags = if self.stdenv.targetPlatform.system == "i686-linux" then
          [
            "-DARCH=i686"
            "-DPLATFORM=nano" # we currently only support nano platform on i686
          ]
        else if self.stdenv.targetPlatform.system == "aarch64-linux" then
          [
            "-DARCH=aarch64"
          ]
        else if self.stdenv.targetPlatform.system == "x86_64-linux" then
          [
            "-DARCH=x86_64"
          ]
        else
          [];

        cmakeFlags = this.archFlags;

        meta = {
          description = "Run your application with zero overhead";
          homepage = "https://www.includeos.org/";
          license = prev.lib.licenses.asl20;
        };
      });
    });
}
