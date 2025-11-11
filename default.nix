# ./default.nix
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
    overlays = overlays;
    config = { };

    # crossSystem = {
    #   config = "aarch64-unknown-linux-musl";
    # };

    # crossSystem = {
    #   config = "x86_64-unknown-linux-musl";
    # };

    # Build machine (the system running nix-build)
    buildSystem = "x86_64-linux";

    # Host machine (the system the compiler itself runs on)
    localSystem = {
      system = "x86_64-linux";
      config = "x86_64-unknown-linux-musl";
    };

    # Target machine (the system for which you are building binaries)
    crossSystem = {
      # config = "aarch64-unknown-linux-musl";
      config = "x86_64-unknown-linux-musl";
    };

  }
}:

pkgs.pkgsIncludeOS.includeos
