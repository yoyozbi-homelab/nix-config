# Custom packages, that can be defined similarly to ones from nixpkgs
# Build them using 'nix build .#example' or (legacy) 'nix-build -A example'
{
  pkgs ? (import ../nixpkgs.nix) { },
}:
{
  #distrobox = pkgs.callPackage ./distrobox.nix { };
  kDrive = pkgs.callPackage ./kDrive { };
  sddm-themes = pkgs.callPackage ./sddm-themes.nix { };
  eclipse202306 = pkgs.callPackage ./eclipse-202306 { };
  superProductivity = pkgs.callPackage ./superProductivity.nix { };
  devToys = pkgs.callPackage ./devToys.nix { };
  appflowy = pkgs.callPackage ./appflowy.nix { };
  affine = pkgs.callPackage ./affine.nix { };
  #zed-editor = pkgs.callPackage ./zed-editor { };
}
