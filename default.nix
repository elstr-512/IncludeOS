{ withCcache ? false, # Enable ccache. Requires correct permissions, see overlay.nix.
  smp ? false, # Enable multcore support (SMP)
  nixpkgs ? ./pinned.nix,
  overlays ? [
    (import ./overlay.nix { inherit withCcache; inherit smp; } )
  ],
  pkgs ? import nixpkgs { config = {}; inherit overlays; }
}:


  pkgs.pkgsIncludeOS.includeos
  # pkgs.pkgsCross.aarch64-multiplatform.pkgsIncludeOS.includeos
