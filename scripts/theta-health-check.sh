#!/usr/bin/env bash
# FILENAME: scripts/theta-health-check.sh
#
# Standard health check for a theta-* repository.
# Usage:
#   theta-health-check.sh [repo-dir] [--skip-nix-build]

set -euo pipefail

REPO_DIR="${1:-.}"
SKIP_NIX_BUILD=0
if [[ ${2:-} == "--skip-nix-build" ]] || [[ ${1:-} == "--skip-nix-build" ]]; then
  SKIP_NIX_BUILD=1
  if [[ ${1:-} == "--skip-nix-build" ]]; then
    REPO_DIR="."
  fi
fi

cd "${REPO_DIR}"
REPO_NAME="$(basename "$(pwd)")"
echo "=================================================================="
echo "Running theta health check for: ${REPO_NAME} ($(pwd))"
echo "=================================================================="

# 0. Verify single shared nixpkgs pin against ../theta-utils/flake.lock
if [[ -f "flake.lock" ]] && [[ -f "../theta-utils/flake.lock" ]] && [[ ${REPO_NAME} != "theta-utils" ]]; then
  EXPECTED_REV="$(grep -A 6 '"nixpkgs": {' ../theta-utils/flake.lock | grep '"rev":' | head -n 1 | sed -E 's/.*"rev":[[:space:]]*"([^"]+)".*/\1/')"
  ACTUAL_REVS="$(grep -A 6 '"nixpkgs": {' flake.lock | grep '"rev":' | sed -E 's/.*"rev":[[:space:]]*"([^"]+)".*/\1/' | sort -u)"
  for rev in ${ACTUAL_REVS}; do
    if [[ ${rev} != "${EXPECTED_REV}" ]]; then
      echo "ERROR: ${REPO_NAME}/flake.lock uses nixpkgs rev ${rev}, expected ${EXPECTED_REV} from theta-utils/flake.lock!" >&2
      echo "       Ensure flake.nix sets 'nixpkgs.follows = \"theta-utils/nixpkgs\";'" >&2
      exit 1
    fi
  done
  echo "[0/7] Verified nixpkgs pin matches theta-utils (${EXPECTED_REV:0:12}) ..."
fi

# 1. Header pragma once & file banner check
if [[ -d "include/theta" ]]; then
  echo "[1/7] Checking public headers under include/theta/ ..."
  while IFS= read -r -d '' hdr; do
    if ! grep -q "^#pragma once" "${hdr}"; then
      echo "ERROR: Missing '#pragma once' in ${hdr}" >&2
      exit 1
    fi
    if grep -Eq "^[[:space:]]*using[[:space:]]+namespace[[:space:]]+" "${hdr}"; then
      echo "ERROR: Forbidden header-scope 'using namespace' in ${hdr}" >&2
      exit 1
    fi
  done < <(find include/theta -type f \( -name '*.h' -o -name '*.hpp' \) -print0)
else
  echo "[1/7] No include/theta/ directory found; skipping header check."
fi

# 2. Formatter / Linter check
if command -v treefmt >/dev/null 2>&1; then
  echo "[2/7] Running treefmt linter & formatter check ..."
  treefmt --fail-on-change
else
  echo "[2/7] treefmt not in PATH; skipping (run inside 'nix develop' or via 'nix fmt')."
fi

# 3. Standard CMake configure & -Werror build
if [[ -f "CMakeLists.txt" ]]; then
  echo "[3/7] Configuring and building with CMake + Ninja (-Werror) ..."
  BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/theta-health-${REPO_NAME}.XXXXXX")"
  trap 'rm -rf "${BUILD_DIR}"' EXIT

  BUILD_BENCHMARK=ON cmake -B "${BUILD_DIR}" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_TESTING=ON

  cmake --build "${BUILD_DIR}"

  # Build self-contained header check target if defined
  if ninja -C "${BUILD_DIR}" -t targets all 2>/dev/null | grep -q "^theta_header_check:"; then
    echo "      Verifying self-contained headers (theta_header_check) ..."
    cmake --build "${BUILD_DIR}" --target theta_header_check
  fi

  # 4. Run unit tests
  echo "[4/7] Running CTest unit test suite ..."
  ctest --test-dir "${BUILD_DIR}" --output-on-failure

  # 5. Benchmark smoke pass
  echo "[5/7] Running benchmark smoke checks ..."
  while IFS= read -r -d '' bench_bin; do
    echo "      Smoke-testing benchmark: $(basename "${bench_bin}")"
    "${bench_bin}" --benchmark_min_time=0.001s >/dev/null
  done < <(find "${BUILD_DIR}" -maxdepth 3 -type f -executable \( -name '*bench*' -o -name '*_bm' \) -print0)
else
  echo "[3-5/7] No CMakeLists.txt found; skipping CMake build/test/benchmark steps."
fi

# 6. Formal verification check (Lean 4)
if [[ -d "verification" ]] && find verification -maxdepth 1 -name '*.lean' | grep -q .; then
  echo "[6/7] Auditing Lean 4 formal proofs in verification/ ..."
  for lean_file in verification/*.lean; do
    if grep -En '\b(sorry|admit|axiom)\b' "${lean_file}" | grep -v '^[0-9]*:[[:space:]]*--'; then
      echo "ERROR: Banned proof token (sorry/admit/axiom) found in ${lean_file}" >&2
      exit 1
    fi
    if command -v lean >/dev/null 2>&1; then
      lean "${lean_file}"
    fi
  done
else
  echo "[6/7] No verification/*.lean files found; skipping Lean 4 proof gate."
fi

# 7. nix build & install artifact check (CMake config + pkg-config .pc + headers)
if [[ ${SKIP_NIX_BUILD} -eq 0 ]] && [[ -f "flake.nix" ]] && command -v nix >/dev/null 2>&1; then
  echo "[7/7] Running 'nix build' and verifying standard install outputs ..."
  OUT_LINK="$(mktemp -u "${TMPDIR:-/tmp}/theta-nix-result-${REPO_NAME}.XXXXXX")"
  nix build -o "${OUT_LINK}"

  if [[ -d "include/theta" ]] && [[ ! -d "${OUT_LINK}/include/theta" ]]; then
    echo "ERROR: nix build output missing ${OUT_LINK}/include/theta" >&2
    rm -f "${OUT_LINK}"
    exit 1
  fi

  if [[ ! -d "${OUT_LINK}/lib/cmake" ]] || ! find "${OUT_LINK}/lib/cmake" -name '*-config.cmake' | grep -q .; then
    echo "ERROR: nix build output missing CMake config in ${OUT_LINK}/lib/cmake/" >&2
    rm -f "${OUT_LINK}"
    exit 1
  fi

  if [[ ! -d "${OUT_LINK}/lib/pkgconfig" ]] || ! find "${OUT_LINK}/lib/pkgconfig" -name '*.pc' | grep -q .; then
    echo "ERROR: nix build output missing pkg-config (.pc) in ${OUT_LINK}/lib/pkgconfig/" >&2
    rm -f "${OUT_LINK}"
    exit 1
  fi

  if command -v pkg-config >/dev/null 2>&1; then
    for pc in "${OUT_LINK}"/lib/pkgconfig/*.pc; do
      pkg-config --validate "${pc}"
    done
  fi

  rm -f "${OUT_LINK}"
else
  echo "[7/7] Skipping 'nix build' check."
fi

echo "✅ Health check PASSED for ${REPO_NAME}!"
