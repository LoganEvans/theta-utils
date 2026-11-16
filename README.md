<!-- FILENAME: README.md -->

# `theta-utils` — Shared Nix/CMake Infrastructure, Linters, Health Checks & Debug Utilities

Central utility repository for the `theta` C++ suite, providing both **zero-runtime-dependency build/lint/packaging helpers** and **optional C++ runtime debug utilities**.

## 1. Zero-Overhead Build & Packaging Helpers (`packages.<system>.cmake` & `lib.mkThetaFlake`)
Downstream `theta-*` repositories can consume `theta-utils.packages.${system}.cmake` in `nativeBuildInputs` (build-time only, adding **zero** runtime dependencies to downstream users):
- **`cmake/ThetaBuild.cmake`**:
  - `theta_enable_strict_warnings()`: Enables C++23, `-Wall -Wextra -Wpedantic -Werror -Wthread-safety -Wconversion -Wsign-conversion -Wshadow ...` and `compile_commands.json` generation.
  - `theta_add_header_check()`: Verifies every public header under `include/theta/` compiles standalone when included first in a translation unit.
  - `theta_install_package(TARGETS ...)`: Automatically installs headers, libraries, `lib/cmake/<pkg>/<pkg>-config.cmake` (`NAMESPACE theta::`), and `lib/pkgconfig/<pkg>.pc`.
- **`nix/mkThetaFlake.nix`**:
  - Wires `packages.{default,test,benchmark}`, `devShells.default` (with `clang-tools`, `cmake-format`, `nixfmt`, `shellcheck`, `shfmt`, `ruff`, `ninja`, `gdb`, `perf`), `formatter` (`nix fmt`), and `checks` (`nix flake check`).
- **`scripts/theta-health-check.sh`** (`theta-health-check`):
  - Runs the 7-stage repository health check (header hygiene, `treefmt` linters, `-Werror` Ninja build + `theta_header_check`, `ctest`, benchmark smoke run, Lean 4 proof audit, and `nix build` output validation for headers, CMake config, and `pkg-config`).

## 2. Optional C++ Debug Utilities (`packages.<system>.default`)
- `theta::debug-utils` (`include/theta/debug-utils/debug.h`): Scoped indentation-aware debug tracer.
- `theta::stacktrace-signal-handlers`: Automatic `cpptrace` stacktrace printer on fatal signals.
