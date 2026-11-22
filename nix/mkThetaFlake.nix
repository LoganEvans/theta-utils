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
  pgoTrainFilter ? null,
  pgoTrainMinTime ? "100x",
  extraPackageArgs ? { },
}:
flake-utils.lib.eachDefaultSystem (
  system:
  let
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };

    treefmtEval = treefmt-nix.lib.evalModule pkgs treefmtModule;

    fnArgs = builtins.functionArgs (import packageFn);
    candidateArgs = {
      src = self;
      theta-utils = theta-utils-self.packages.${system}.default;
      theta-cmake = theta-utils-self.packages.${system}.cmake;
    }
    // extraPackageArgs;
    filteredArgs = builtins.intersectAttrs fnArgs candidateArgs // {
      src = self;
    };

    drv = pkgs.callPackage packageFn filteredArgs;

    llvmTools = [
      pkgs.llvmPackages_23.bintools
      pkgs.llvmPackages_23.llvm
    ];

    pgoFilterArg =
      if pgoTrainFilter == null then
        ""
      else
        "--benchmark_filter=${pkgs.lib.escapeShellArg pgoTrainFilter}";

    pgoStage1Profdata = drv.overrideAttrs (oldAttrs: {
      pname = "${pname}-pgo-stage1-profdata";
      outputs = [ "out" ];
      separateDebugInfo = false;
      doCheck = false;
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ llvmTools;
      cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
        "-DBUILD_TESTING=OFF"
        "-DTHETA_ENABLE_LTO=ON"
        "-DTHETA_PGO_GENERATE=ON"
      ];
      env = (oldAttrs.env or { }) // {
        BUILD_BENCHMARK = "ON";
      };
      installPhase = ''
        runHook preInstall
        mkdir -p "$TMPDIR/pgo-stage1" "$out"
        found=0
        while IFS= read -r -d "" bench_bin; do
          found=1
          echo "[pgo-stage1] Training IR PGO on $(basename "$bench_bin") (${pgoTrainMinTime})..."
          LLVM_PROFILE_FILE="$TMPDIR/pgo-stage1/ir_%p_%m.profraw" \
            "$bench_bin" --benchmark_min_time=${pkgs.lib.escapeShellArg pgoTrainMinTime} ${pgoFilterArg} >/dev/null
        done < <(find . -maxdepth 3 -type f -executable \( -name '*bench*' -o -name '*_bm' \) -print0)
        if [ "$found" -eq 0 ]; then
          echo "ERROR: No benchmark executables found for PGO Stage-1 training" >&2
          exit 1
        fi
        llvm-profdata merge -output="$out/stage1.profdata" "$TMPDIR/pgo-stage1"/*.profraw
        runHook postInstall
      '';
    });

    pgoProfdata = drv.overrideAttrs (oldAttrs: {
      pname = "${pname}-cspgo-profdata";
      outputs = [ "out" ];
      separateDebugInfo = false;
      doCheck = false;
      nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ llvmTools;
      cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
        "-DBUILD_TESTING=OFF"
        "-DTHETA_ENABLE_LTO=ON"
        "-DTHETA_PGO_PROFILE=${pgoStage1Profdata}/stage1.profdata"
        "-DTHETA_CSPGO_GENERATE=ON"
      ];
      env = (oldAttrs.env or { }) // {
        BUILD_BENCHMARK = "ON";
      };
      installPhase = ''
        runHook preInstall
        mkdir -p "$TMPDIR/pgo-stage2" "$out"
        while IFS= read -r -d "" bench_bin; do
          echo "[pgo-stage2] Training CS-PGO on $(basename "$bench_bin") (${pgoTrainMinTime})..."
          LLVM_PROFILE_FILE="$TMPDIR/pgo-stage2/cs_%p_%m.profraw" \
            "$bench_bin" --benchmark_min_time=${pkgs.lib.escapeShellArg pgoTrainMinTime} ${pgoFilterArg} >/dev/null
        done < <(find . -maxdepth 3 -type f -executable \( -name '*bench*' -o -name '*_bm' \) -print0)
        llvm-profdata merge \
          -output="$out/merged_cspgo.profdata" \
          "${pgoStage1Profdata}/stage1.profdata" \
          "$TMPDIR/pgo-stage2"/*.profraw
        runHook postInstall
      '';
    });
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
        cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
          "-DTHETA_ENABLE_LTO=OFF"
        ];
        env = (oldAttrs.env or { }) // {
          BUILD_BENCHMARK = "ON";
        };
      });

      benchmark-lto = drv.overrideAttrs (oldAttrs: {
        pname = "${pname}-benchmark-lto";
        doCheck = true;
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ llvmTools;
        cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
          "-DTHETA_ENABLE_LTO=ON"
        ];
        env = (oldAttrs.env or { }) // {
          BUILD_BENCHMARK = "ON";
        };
      });

      pgo-profdata = pgoProfdata;

      benchmark-pgo = drv.overrideAttrs (oldAttrs: {
        pname = "${pname}-benchmark-pgo";
        doCheck = true;
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ llvmTools;
        cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
          "-DTHETA_ENABLE_LTO=ON"
          "-DTHETA_PGO_PROFILE=${pgoProfdata}/merged_cspgo.profdata"
        ];
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
        pkgs.perf
        pkgs.llvmPackages_23.bintools
        pkgs.llvmPackages_23.llvm
        pkgs.cmake-format
        pkgs.nixfmt
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
