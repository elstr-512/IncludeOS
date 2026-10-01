# uboot-aarch64.nix

let
  nixpkgs = import ../pinned.nix;
  pkgsAarch64 = nixpkgs {
    system = "aarch64-linux";
  };
in

pkgsAarch64.ubootQemuAarch64
