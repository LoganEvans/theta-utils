# FILENAME: flake.nix
{
  description = "theta-utils: Shared <theta/arch.hpp> capability traits, Nix/CMake build helpers, linters, and health checks";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      treefmt-nix,
    }:
    (flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        theta-utils-drv = pkgs.callPackage ./package.nix {
          src = self;
          cmakeOnly = false;
        };

        theta-cmake-drv = pkgs.callPackage ./package.nix {
          src = self;
          cmakeOnly = true;
        };

        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in
      {
        packages = rec {
          theta-utils = theta-utils-drv;
          cmake = theta-cmake-drv;

          test = theta-utils-drv.overrideAttrs (_attrs: {
            cmakeBuildType = "Debug";
            doCheck = true;
          });

          default = theta-utils-drv;
        };

        devShells.default = theta-utils-drv.overrideAttrs (oldAttrs: {
          cmakeBuildType = "Debug";
          doCheck = true;
          nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
            pkgs.ninja
            pkgs.gdb
            pkgs.perf
            pkgs.llvmPackages_23.clang-tools
            pkgs.cmake-format
            pkgs.nixfmt
            pkgs.shellcheck
            pkgs.shfmt
            pkgs.ruff
            treefmtEval.config.build.wrapper
          ];
        });

        formatter = treefmtEval.config.build.wrapper;

        checks = {
          formatting = treefmtEval.config.build.check self;
          test = theta-utils-drv.overrideAttrs (_attrs: {
            cmakeBuildType = "Debug";
            doCheck = true;
          });
        };
      }
    ))
    // {
      lib = {
        mkThetaFlake = import ./nix/mkThetaFlake.nix {
          inherit nixpkgs flake-utils treefmt-nix;
          theta-utils-self = self;
        };
        cmakeDir = "${self}/cmake";
        clangFormatConfig = "${self}/.clang-format";
        clangTidyConfig = "${self}/.clang-tidy";
      };
    };
}
