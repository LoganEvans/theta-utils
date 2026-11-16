# FILENAME: nix/mkThetaFlake.nix
{
  nixpkgs,
  flake-utils,
  treefmt-nix,
  theta-utils-self,
}:
{
  self,
  pname,
  packageFn,
  treefmtModule ? ../treefmt.nix,
}:
flake-utils.lib.eachDefaultSystem (
  system:
  let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    treefmtEval = treefmt-nix.lib.evalModule pkgs treefmtModule;

    drv = pkgs.callPackage packageFn {
      src = self;
      theta-utils = theta-utils-self.packages.${system}.default;
      theta-cmake = theta-utils-self.packages.${system}.cmake;
    };
  in
  {
    packages = {
      ${pname} = drv;
      default = drv;

      test = drv.overrideAttrs (oldAttrs: {
        cmakeBuildType = "Debug";
        doCheck = true;
      });

      benchmark = drv.overrideAttrs (oldAttrs: {
        doCheck = true;
        env = (oldAttrs.env or { }) // {
          BUILD_BENCHMARK = "ON";
        };
      });
    };

    devShells.default = drv.overrideAttrs (oldAttrs: {
      cmakeBuildType = "Debug";
      doCheck = true;
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
        pkgs.ninja
        pkgs.gdb
        pkgs.linuxPackages.perf
        pkgs.cmake-format
        pkgs.nixfmt-rfc-style
        pkgs.shellcheck
        pkgs.shfmt
        pkgs.ruff
        theta-utils-self.packages.${system}.cmake
        treefmtEval.config.build.wrapper
      ];
    });

    formatter = treefmtEval.config.build.wrapper;

    checks = {
      formatting = treefmtEval.config.build.check self;
      test = drv.overrideAttrs (oldAttrs: {
        cmakeBuildType = "Debug";
        doCheck = true;
      });
    };
  }
)
