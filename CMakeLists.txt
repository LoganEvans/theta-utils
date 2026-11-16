# FILENAME: CMakeLists.txt

cmake_minimum_required(VERSION 3.25)
project(theta-utils VERSION 0.1.0 LANGUAGES CXX)

include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/ThetaBuild.cmake")

option(THETA_UTILS_CMAKE_ONLY "Install only CMake/linter/health-check utilities without C++ runtime deps" OFF)

install(
    PROGRAMS "${CMAKE_CURRENT_SOURCE_DIR}/scripts/theta-health-check.sh"
    DESTINATION "${CMAKE_INSTALL_BINDIR}"
    RENAME "theta-health-check"
)

if(THETA_UTILS_CMAKE_ONLY)
  add_library(theta-cmake INTERFACE)
  add_library(theta::theta-cmake ALIAS theta-cmake)
  theta_install_package(
      PACKAGE_NAME theta-cmake
      NO_HEADERS
      TARGETS theta-cmake
      DESCRIPTION "Shared CMake & health-check utilities for the theta C++ suite"
      EXTRA_CMAKE_INCLUDE "ThetaBuild.cmake"
      EXTRA_CMAKE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/cmake/ThetaBuild.cmake"
  )
  return()
endif()

theta_enable_strict_warnings()
theta_add_header_check()

find_package(fmt CONFIG REQUIRED)

add_library(debug-utils SHARED src/debug.cc)
add_library(theta::debug-utils ALIAS debug-utils)
target_include_directories(
    debug-utils PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(debug-utils PUBLIC fmt::fmt)

add_library(stacktrace-signal-handlers SHARED src/stacktrace-signal-handlers.cc)
add_library(theta::stacktrace-signal-handlers ALIAS stacktrace-signal-handlers)
target_include_directories(
    stacktrace-signal-handlers PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)
target_link_libraries(stacktrace-signal-handlers PUBLIC cpptrace fmt::fmt)

theta_install_package(
    TARGETS debug-utils stacktrace-signal-handlers
    DESCRIPTION "Debug tracing, stacktrace signal handlers, and CMake build utilities for theta"
    EXTRA_CMAKE_INCLUDE "ThetaBuild.cmake"
    EXTRA_CMAKE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/cmake/ThetaBuild.cmake"
)

if(BUILD_TESTING)
  add_subdirectory(test)
endif()
