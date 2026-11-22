# FILENAME: CMakeLists.txt

cmake_minimum_required(VERSION 3.25)
project(
  theta-utils
  VERSION 0.1.0
  LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/ThetaBuild.cmake")

option(
  THETA_UTILS_CMAKE_ONLY
  "Install only CMake/linter/health-check utilities under theta-cmake package name"
  OFF)

install(
  PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/scripts/theta-health-check.sh"
  DESTINATION "${CMAKE_INSTALL_BINDIR}"
  RENAME "theta-health-check")

add_library(theta-cmake INTERFACE)
add_library(theta::theta-cmake ALIAS theta-cmake)
target_include_directories(
  theta-cmake INTERFACE $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
                        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

if(THETA_UTILS_CMAKE_ONLY)
  install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/include/theta/arch.hpp"
          DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/theta")
  theta_install_package(
    PACKAGE_NAME
    theta-cmake
    NO_HEADERS
    TARGETS
    theta-cmake
    DESCRIPTION
    "Shared CMake, <theta/arch.hpp> traits, & health-check utilities for theta"
    EXTRA_CMAKE_INCLUDE
    "ThetaBuild.cmake"
    EXTRA_CMAKE_FILES
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/ThetaBuild.cmake")
  return()
endif()

theta_enable_strict_warnings()
theta_add_header_check()

add_library(theta-utils INTERFACE)
add_library(theta::theta-utils ALIAS theta-utils)
target_include_directories(
  theta-utils INTERFACE $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
                        $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>)

if(BUILD_TESTING)
  find_package(GTest REQUIRED)
  include(GoogleTest)

  add_executable(arch_test tests/arch_test.cpp)
  target_link_libraries(arch_test PRIVATE theta::theta-utils GTest::gtest_main)
  gtest_discover_tests(arch_test)
endif()

theta_install_package(
  TARGETS
  theta-utils
  theta-cmake
  DESCRIPTION
  "Shared <theta/arch.hpp> capability traits, CMake build helpers, and health checks for theta"
  EXTRA_CMAKE_INCLUDE
  "ThetaBuild.cmake"
  EXTRA_CMAKE_FILES
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/ThetaBuild.cmake")
