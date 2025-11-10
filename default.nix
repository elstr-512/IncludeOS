{
  nixpkgs ? ./pinned.nix

  # Enable ccache support. See overlay.nix for details.
, withCcache ? false

  # Enable multicore suport.
, smp ? false

, overlays ? [
    ( import ./overlay.nix { inherit withCcache; inherit smp; } )
  ]

, pkgs ? import nixpkgs {
    inherit overlays;
    config = { };

    # crossSystem = {
    #   config = "aarch64-unknown-linux-musl";
    # };

  }
}:

pkgs.pkgsIncludeOS.includeos

# pkgs.pkgsCross.aarch64-multiplatform.pkgsIncludeOS.includeos
