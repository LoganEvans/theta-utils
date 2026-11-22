# FILENAME: treefmt.nix
{ pkgs, ... }:
{
  projectRootFile = "flake.nix";

  programs.clang-format.enable = true;
  programs.clang-format.package = pkgs.llvmPackages_23.clang-tools;
  programs.cmake-format.enable = true;
  programs.cmake-format.includes = [
    "*CMakeLists.txt"
    "cmake/*.cmake"
  ];
  programs.nixfmt.enable = true;
  programs.shellcheck.enable = true;
  programs.shfmt.enable = true;
  programs.ruff-check.enable = true;
  programs.ruff-format.enable = true;
}
