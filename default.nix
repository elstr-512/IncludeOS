# ./default.nix
{
  nixpkgs ? ./pinned.nix

, withCcache ? false

, smp ? false

, overlays ? [
    ( import ./overlay.nix { inherit withCcache; inherit smp; } )
  ]

, pkgs ? import nixpkgs {
    inherit overlays;
    config = { };

    crossSystem = {
      config = "aarch64-unknown-linux-musl";
    };

  }
}:

pkgs.pkgsIncludeOS.includeos
