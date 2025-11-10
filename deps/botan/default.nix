{
  pkgs
}:

pkgs.botan2.overrideAttrs (oldAttrs: {
  postInstall = (oldAttrs.postInstall or "") + ''
    ln -sr "$out/include/botan-2/botan" "$out/include"
  '';
})
