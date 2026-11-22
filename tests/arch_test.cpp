// FILENAME: tests/arch_test.cpp
// Copyright (c) 2026 Logan Evans
// SPDX-License-Identifier: MIT

#include <gtest/gtest.h>

#include <theta/arch.hpp>

namespace theta::arch {
namespace {

TEST(ArchTraitsTest, ZeroOneMacrosAreMutuallyConsistentWithConstexprTraits) {
  static_assert((THETA_ARCH_X86_64 == 0) || (THETA_ARCH_X86_64 == 1));
  static_assert((THETA_ARCH_AARCH64 == 0) || (THETA_ARCH_AARCH64 == 1));
  static_assert(!(kIsX86_64 && kIsAarch64));
  static_assert(kIsX86_64 == (THETA_ARCH_X86_64 != 0));
  static_assert(kIsAarch64 == (THETA_ARCH_AARCH64 != 0));
  static_assert(kIsLinux == (THETA_OS_LINUX != 0));
  static_assert(kHasLinuxRseq == (THETA_HAS_LINUX_RSEQ != 0));
  static_assert((THETA_ARCH_X86_BMI == 0) || (THETA_ARCH_X86_BMI == 1));
  static_assert((THETA_ARCH_X86_BMI2 == 0) || (THETA_ARCH_X86_BMI2 == 1));
  static_assert(kHasBmi == (THETA_ARCH_X86_BMI != 0));
  static_assert(kHasBmi2 == (THETA_ARCH_X86_BMI2 != 0));
  static_assert(!kHasBmi2 || kIsX86_64);
  static_assert(kCacheLineBytes == 64U);

  EXPECT_EQ(kCacheLineBytes, 64U);
}

TEST(ArchTraitsTest, CpuRelaxExecutesCleanly) {
  for (int i = 0; i < 8; ++i) {
    cpu_relax();
  }
  SUCCEED();
}

}  // namespace
}  // namespace theta::arch
