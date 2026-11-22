<!-- FILENAME: README.md -->

# `theta-utils` — Shared `<theta/arch.hpp>` Traits, Nix/CMake Infrastructure, Linters & Health Checks

Central zero-runtime-dependency infrastructure repository for the `theta` C++23 suite.

*(Note: C++ scoped debug tracing, `WelfordStats`, Calling Context Trees, and `stacktrace-signal-handlers` live in the standalone `theta-debug-utils` repository under `<theta/debug_utils.hpp>` and `<theta/debug.hpp>`.)*

## Components (`packages.<system>.cmake`, `packages.<system>.default`, & `lib.mkThetaFlake`)

1. **`include/theta/arch.hpp`**:
   - Layer 1 `-Wundef`-safe `0`/`1` preprocessor macros (`THETA_ARCH_X86_64`, `THETA_ARCH_AARCH64`, `THETA_OS_LINUX`, `THETA_HAS_LINUX_RSEQ`, `THETA_SIMD_*`, `THETA_TSAN_ENABLED`, `THETA_ASAN_ENABLED`).
   - Layer 2 `namespace theta::arch` `constexpr` capability traits (`kIsX86_64`, `kIsAarch64`, `kCacheLineBytes`, `kHasRedZoneStlfPause`, `kHasEvexHighRegs`, `kAvx512DoublePumped`, `kHasFastFsrm`, `cpu_relax()`).
2. **`cmake/ThetaBuild.cmake`**:
   - `theta_enable_strict_warnings()`: Enables C++23, strict `-Werror` warning flags, ThinLTO/CS-PGO options, `theta_link_pool=2`, and `compile_commands.json` generation.
   - `theta_add_header_check()`: Verifies every header under `include/theta/` compiles standalone when included first in an isolated translation unit.
   - `theta_install_package(TARGETS ...)`: Installs headers, libraries, `lib/cmake/<pkg>/<pkg>-config.cmake` (`NAMESPACE theta::`), and `lib/pkgconfig/<pkg>.pc`.
3. **`nix/mkThetaFlake.nix`**:
   - Wires `packages.{default,test,benchmark,benchmark-lto,pgo-profdata,benchmark-pgo}`, `devShells.default`, `formatter` (`nix fmt`), and `checks` (`nix flake check`), plus optional `extraPackageArgs` for sibling `theta-*` dependencies.
4. **`scripts/theta-health-check.sh`** (`theta-health-check`):
   - Runs the 7-stage repository health check (shared `nixpkgs` pin check, header hygiene, `treefmt` linters, `-Werror` Ninja build + `theta_header_check`, `ctest`, benchmark smoke run, Lean 4 proof audit, and `nix build` + `pkg-config --validate`).
