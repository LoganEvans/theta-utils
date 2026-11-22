// FILENAME: include/theta/arch.hpp
// Copyright (c) 2026 Logan Evans
// SPDX-License-Identifier: MIT

#pragma once

#include <cstddef>
#include <cstdint>

// ============================================================================
// Layer 1: -Wundef-safe 0/1 Preprocessor Macros
// Use ONLY at `#include` dispatch boundaries and target-gated intrinsic /
// inline-`asm` blocks. Inside C++ logic, prefer `theta::arch::*` constexprs.
// ============================================================================

#if defined(__x86_64__) || defined(_M_X64)
#define THETA_ARCH_X86_64 1
#else
#define THETA_ARCH_X86_64 0
#endif

#if defined(__aarch64__) || defined(_M_ARM64)
#define THETA_ARCH_AARCH64 1
#else
#define THETA_ARCH_AARCH64 0
#endif

#if defined(__linux__)
#define THETA_OS_LINUX 1
#else
#define THETA_OS_LINUX 0
#endif

#if THETA_OS_LINUX && __has_include(<sys/rseq.h>)
#define THETA_HAS_LINUX_RSEQ 1
#else
#define THETA_HAS_LINUX_RSEQ 0
#endif

// Sanitizer detection
#if defined(__SANITIZE_THREAD__)
#define THETA_TSAN_ENABLED 1
#elif defined(__has_feature)
#if __has_feature(thread_sanitizer)
#define THETA_TSAN_ENABLED 1
#else
#define THETA_TSAN_ENABLED 0
#endif
#else
#define THETA_TSAN_ENABLED 0
#endif

#if defined(__SANITIZE_ADDRESS__)
#define THETA_ASAN_ENABLED 1
#elif defined(__has_feature)
#if __has_feature(address_sanitizer)
#define THETA_ASAN_ENABLED 1
#else
#define THETA_ASAN_ENABLED 0
#endif
#else
#define THETA_ASAN_ENABLED 0
#endif

// x86-64 SIMD & ISA feature macros
#if THETA_ARCH_X86_64 && defined(__SSE2__)
#define THETA_SIMD_SSE2 1
#else
#define THETA_SIMD_SSE2 0
#endif

#if THETA_ARCH_X86_64 && defined(__AVX2__)
#define THETA_SIMD_AVX2 1
#else
#define THETA_SIMD_AVX2 0
#endif

#if THETA_ARCH_X86_64 && defined(__AVX512F__)
#define THETA_SIMD_AVX512F 1
#else
#define THETA_SIMD_AVX512F 0
#endif

#if THETA_ARCH_X86_64 && defined(__AVX512BW__)
#define THETA_SIMD_AVX512BW 1
#else
#define THETA_SIMD_AVX512BW 0
#endif

#if THETA_ARCH_X86_64 && defined(__AVX512VL__)
#define THETA_SIMD_AVX512VL 1
#else
#define THETA_SIMD_AVX512VL 0
#endif

#if THETA_ARCH_X86_64 && defined(__AVX512VBMI__)
#define THETA_SIMD_AVX512VBMI 1
#else
#define THETA_SIMD_AVX512VBMI 0
#endif

#if THETA_ARCH_X86_64 && defined(__AVX512VBMI2__)
#define THETA_SIMD_AVX512VBMI2 1
#else
#define THETA_SIMD_AVX512VBMI2 0
#endif

#if THETA_ARCH_X86_64 && defined(__BMI__)
#define THETA_ARCH_X86_BMI 1
#else
#define THETA_ARCH_X86_BMI 0
#endif

#if THETA_ARCH_X86_64 && defined(__BMI2__)
#define THETA_ARCH_X86_BMI2 1
#else
#define THETA_ARCH_X86_BMI2 0
#endif

// AArch64 SIMD & ISA feature macros
#if THETA_ARCH_AARCH64 && defined(__ARM_NEON)
#define THETA_SIMD_NEON 1
#else
#define THETA_SIMD_NEON 0
#endif

#if THETA_ARCH_AARCH64 && defined(__ARM_FEATURE_SVE)
#define THETA_SIMD_SVE 1
#else
#define THETA_SIMD_SVE 0
#endif

#if THETA_ARCH_AARCH64 && defined(__ARM_FEATURE_SVE2)
#define THETA_SIMD_SVE2 1
#else
#define THETA_SIMD_SVE2 0
#endif

#if THETA_ARCH_AARCH64 && defined(__ARM_FEATURE_ATOMICS)
#define THETA_ARM_HAS_LSE 1
#else
#define THETA_ARM_HAS_LSE 0
#endif

#if THETA_ARCH_AARCH64 && defined(__ARM_FEATURE_QRCPC)
#define THETA_ARM_HAS_RCPC 1
#else
#define THETA_ARM_HAS_RCPC 0
#endif

// Microarchitectural vendor / tuning hints (predefined by Clang or CMake)
#if THETA_ARCH_X86_64 &&                                                  \
    (defined(THETA_X86_VENDOR_AMD) || defined(__znver1__) ||              \
     defined(__znver2__) || defined(__znver3__) || defined(__znver4__) || \
     defined(__znver5__) || defined(__znver6__))
#define THETA_ARCH_X86_AMD 1
#else
#define THETA_ARCH_X86_AMD 0
#endif

#if THETA_ARCH_X86_64 && \
    (defined(THETA_AVX512_DOUBLE_PUMPED) || defined(__znver4__))
#define THETA_ARCH_AVX512_DOUBLE_PUMPED 1
#else
#define THETA_ARCH_AVX512_DOUBLE_PUMPED 0
#endif

// Shared compiler codegen & loop-control attributes
#ifndef THETA_FORCE_INLINE
#define THETA_FORCE_INLINE __attribute__((always_inline)) inline
#endif
#ifndef THETA_NOINLINE
#define THETA_NOINLINE __attribute__((noinline)) inline
#endif
#ifndef THETA_ALIGNED_NOINLINE
#define THETA_ALIGNED_NOINLINE __attribute__((noinline, aligned(64))) inline
#endif
#ifndef THETA_COLD_NOINLINE
#define THETA_COLD_NOINLINE __attribute__((noinline, cold)) inline
#endif

#ifndef THETA_MUSTTAIL
#if defined(__has_cpp_attribute)
#if defined(__clang__) && __has_cpp_attribute(clang::musttail)
#define THETA_MUSTTAIL [[clang::musttail]]
#elif defined(__GNUC__) && __has_cpp_attribute(gnu::musttail)
#define THETA_MUSTTAIL [[gnu::musttail]]
#else
#define THETA_MUSTTAIL
#endif
#else
#define THETA_MUSTTAIL
#endif
#endif

#ifndef THETA_DISABLE_UNROLL
#if defined(__clang__)
#define THETA_DISABLE_UNROLL _Pragma("clang loop unroll(disable)")
#define THETA_SCALAR_LOOP \
  _Pragma("clang loop vectorize(disable) unroll(disable)")
#elif defined(__GNUC__)
#define THETA_DISABLE_UNROLL
#define THETA_SCALAR_LOOP _Pragma("GCC novector")
#else
#define THETA_DISABLE_UNROLL
#define THETA_SCALAR_LOOP
#endif
#endif

// ============================================================================
// Layer 2: `theta::arch` Compile-Time Capability & Behavioral Traits
// Prefer these inside C++ algorithms, `if constexpr`, and tuning tables.
// ============================================================================
namespace theta::arch {

inline constexpr bool kIsX86_64 = (THETA_ARCH_X86_64 != 0);
inline constexpr bool kIsAarch64 = (THETA_ARCH_AARCH64 != 0);
inline constexpr bool kIsLinux = (THETA_OS_LINUX != 0);
inline constexpr bool kHasLinuxRseq = (THETA_HAS_LINUX_RSEQ != 0);

inline constexpr bool kTsanEnabled = (THETA_TSAN_ENABLED != 0);
inline constexpr bool kAsanEnabled = (THETA_ASAN_ENABLED != 0);

inline constexpr bool kHasSse2 = (THETA_SIMD_SSE2 != 0);
inline constexpr bool kHasAvx2 = (THETA_SIMD_AVX2 != 0);
inline constexpr bool kHasAvx512F = (THETA_SIMD_AVX512F != 0);
inline constexpr bool kHasAvx512Bw = (THETA_SIMD_AVX512BW != 0);
inline constexpr bool kHasAvx512Vl = (THETA_SIMD_AVX512VL != 0);
inline constexpr bool kHasAvx512Vbmi = (THETA_SIMD_AVX512VBMI != 0);
inline constexpr bool kHasAvx512Vbmi2 = (THETA_SIMD_AVX512VBMI2 != 0);
inline constexpr bool kHasBmi = (THETA_ARCH_X86_BMI != 0);
inline constexpr bool kHasBmi2 = (THETA_ARCH_X86_BMI2 != 0);

inline constexpr bool kHasNeon = (THETA_SIMD_NEON != 0);
inline constexpr bool kHasSve = (THETA_SIMD_SVE != 0);
inline constexpr bool kHasSve2 = (THETA_SIMD_SVE2 != 0);
inline constexpr bool kHasArmLse = (THETA_ARM_HAS_LSE != 0);
inline constexpr bool kHasArmRcpc = (THETA_ARM_HAS_RCPC != 0);

inline constexpr std::size_t kCacheLineBytes = 64U;

// Behavioral microarchitecture traits
// True when the target ABI & uarch provide a 128B stack red-zone and ~15-cycle
// partial Store-to-Load Forwarding reject stall (`movw -6(%rsp) -> movq
// -8(%rsp)`).
inline constexpr bool kHasRedZoneStlfPause = kIsX86_64 && !kTsanEnabled;

// True when EVEX `%xmm16..31` / `%ymm16..31` / `%zmm16..31` are available to
// avoid touching legacy `%ymm0..15` (`vzeroupper`-free vector codegen).
inline constexpr bool kHasEvexHighRegs = kIsX86_64 && kHasAvx512Vl;

// True on AMD Zen microarchitectures (`znver1..znver6`).
inline constexpr bool kX86VendorAmd = (THETA_ARCH_X86_AMD != 0);

// True when 512-bit ZMM instructions are double-pumped over 256-bit execution
// pipes (e.g., AMD Zen 4), favoring 256-bit EVEX `%ymm16..31` loops.
inline constexpr bool kAvx512DoublePumped =
    (THETA_ARCH_AVX512_DOUBLE_PUMPED != 0);

// True on Intel server/client cores with Fast Short REP MOVSB (`FSRM` /
// `ERMS`).
#if defined(__FSRM__)
inline constexpr bool kHasFastFsrm = true;
#else
inline constexpr bool kHasFastFsrm = kIsX86_64 && kHasAvx512F && !kX86VendorAmd;
#endif

// Zero-header-bloat polite SMT / spin-loop pipeline yield hint (`pause` on
// x86-64, low-latency `yield` on AArch64).
THETA_FORCE_INLINE void cpu_relax() noexcept {
#if THETA_ARCH_X86_64
  __builtin_ia32_pause();
#elif THETA_ARCH_AARCH64
  __builtin_arm_yield();
#else
  __atomic_signal_fence(__ATOMIC_SEQ_CST);
#endif
}

}  // namespace theta::arch
