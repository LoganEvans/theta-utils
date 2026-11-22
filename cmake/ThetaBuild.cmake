# FILENAME: cmake/ThetaBuild.cmake

include_guard(GLOBAL)

include(CTest)
include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Throttle concurrent Ninja link jobs (e.g. ThinLTO ld.lld +
# GoogleBenchmark/Abseil) so low-RAM hosts (15-16 GiB) never swap-thrash while
# keeping C++ compilation saturated across physical cores.
if(CMAKE_GENERATOR MATCHES "^Ninja")
  set(THETA_LINK_POOL_JOBS
      "2"
      CACHE
        STRING
        "Maximum concurrent Ninja link jobs to cap ThinLTO/debug memory spikes")
  get_property(_theta_job_pools GLOBAL PROPERTY JOB_POOLS)
  if(NOT _theta_job_pools MATCHES "(^|;)theta_link_pool=")
    set_property(GLOBAL APPEND
                 PROPERTY JOB_POOLS "theta_link_pool=${THETA_LINK_POOL_JOBS}")
  endif()
  if(NOT DEFINED CMAKE_JOB_POOL_LINK)
    set(CMAKE_JOB_POOL_LINK
        "theta_link_pool"
        CACHE STRING "Default Ninja job pool for linking")
  endif()
endif()

# Automatically expose `<theta/arch.hpp>` from either an installed `theta-cmake`
# prefix (`$out/lib/cmake/theta-cmake/../../../include`) or an in-tree sibling
# checkout (`../theta-utils/cmake/../include`).
foreach(_theta_arch_candidate "${CMAKE_CURRENT_LIST_DIR}/../include"
                              "${CMAKE_CURRENT_LIST_DIR}/../../../include")
  if(EXISTS "${_theta_arch_candidate}/theta/arch.hpp")
    get_filename_component(_theta_arch_inc "${_theta_arch_candidate}" REALPATH)
    include_directories("${_theta_arch_inc}")
    break()
  endif()
endforeach()

# ------------------------------------------------------------------------------
# 1. Strict, high-signal compiler warnings + -Werror
# ------------------------------------------------------------------------------
function(theta_enable_strict_warnings)
  if(NOT DEFINED CMAKE_CXX_STANDARD)
    set(CMAKE_CXX_STANDARD
        23
        PARENT_SCOPE)
  endif()
  set(CMAKE_CXX_STANDARD_REQUIRED
      ON
      PARENT_SCOPE)
  set(CMAKE_CXX_EXTENSIONS
      OFF
      PARENT_SCOPE)
  set(CMAKE_EXPORT_COMPILE_COMMANDS
      ON
      PARENT_SCOPE)

  add_compile_options(
    -Wall
    -Wextra
    -Wpedantic
    -Werror
    -Wthread-safety
    -Wconversion
    -Wsign-conversion
    -Wshadow
    -Wnon-virtual-dtor
    -Woverloaded-virtual
    -Wnull-dereference
    -Wdouble-promotion
    -Wformat=2
    -Wimplicit-fallthrough
    -Wundef
    -fzero-call-used-regs=skip
    -fdiagnostics-color=always
    -Wno-unused-command-line-argument)
  add_link_options(-Wno-unused-command-line-argument)

  theta_configure_optimization()
endfunction()

# ------------------------------------------------------------------------------
# 1b. ThinLTO & 2-Stage Context-Sensitive PGO (IR PGO + CS-PGO) Configuration
# ------------------------------------------------------------------------------
macro(theta_configure_optimization)
  option(THETA_ENABLE_LTO "Enable Clang ThinLTO for Release builds" OFF)
  option(THETA_PGO_GENERATE
         "Enable Stage-1 LLVM IR PGO instrumentation (-fprofile-generate)" OFF)
  option(THETA_CSPGO_GENERATE
         "Enable Stage-2 LLVM Context-Sensitive PGO (-fcs-profile-generate)"
         OFF)
  set(THETA_PGO_PROFILE
      ""
      CACHE FILEPATH "Path to merged .profdata profile for -fprofile-use")
  set(THETA_PGO_PROFILE_LIST
      ""
      CACHE FILEPATH "Optional Clang -fprofile-list= allowlist file")

  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    set(_theta_pgo_list "${THETA_PGO_PROFILE_LIST}")
    if("${_theta_pgo_list}" STREQUAL ""
       AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/pgo-profile.list")
      set(_theta_pgo_list "${CMAKE_CURRENT_SOURCE_DIR}/pgo-profile.list")
    endif()
    if(NOT "${_theta_pgo_list}" STREQUAL ""
       AND (THETA_PGO_PROFILE
            OR THETA_PGO_GENERATE
            OR THETA_CSPGO_GENERATE))
      add_compile_options(
        $<$<COMPILE_LANGUAGE:CXX>:-fprofile-list=${_theta_pgo_list}>)
    endif()

    if(THETA_ENABLE_LTO AND CMAKE_BUILD_TYPE MATCHES
                            "^(Release|RelWithDebInfo)$")
      add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-flto=thin>)
      add_link_options(-flto=thin)
      find_program(THETA_LLD_LINKER ld.lld)
      if(THETA_LLD_LINKER)
        add_link_options(-fuse-ld=lld)
      endif()
    endif()

    if(THETA_PGO_PROFILE)
      add_compile_options(
        $<$<COMPILE_LANGUAGE:CXX>:-fprofile-use=${THETA_PGO_PROFILE}>
        $<$<COMPILE_LANGUAGE:CXX>:-Wno-profile-instr-out-of-date>
        $<$<COMPILE_LANGUAGE:CXX>:-Wno-profile-instr-unprofiled>
        $<$<COMPILE_LANGUAGE:CXX>:-Wno-backend-plugin>)
      add_link_options(-fprofile-use=${THETA_PGO_PROFILE})
    endif()

    if(THETA_PGO_GENERATE)
      add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-fprofile-generate>)
      add_link_options(-fprofile-generate)
    endif()

    if(THETA_CSPGO_GENERATE)
      add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-fcs-profile-generate>)
      add_link_options(-fcs-profile-generate)
    endif()
  endif()
endmacro()

# ------------------------------------------------------------------------------
# 1. Self-contained public header verification Compiles an isolated translation
#   unit per header under include/theta/
# ------------------------------------------------------------------------------
function(theta_add_header_check)
  file(GLOB_RECURSE THETA_PUBLIC_HEADERS CONFIGURE_DEPENDS
       "${CMAKE_CURRENT_SOURCE_DIR}/include/theta/*.h"
       "${CMAKE_CURRENT_SOURCE_DIR}/include/theta/*.hpp")

  if(NOT THETA_PUBLIC_HEADERS)
    return()
  endif()

  set(HEADER_CHECK_SRCS "")
  set(idx 0)
  foreach(hdr IN LISTS THETA_PUBLIC_HEADERS)
    file(RELATIVE_PATH rel_hdr "${CMAKE_CURRENT_SOURCE_DIR}/include" "${hdr}")
    set(gen_cc
        "${CMAKE_CURRENT_BINARY_DIR}/theta_header_check/header_${idx}.cc")
    file(
      WRITE "${gen_cc}"
      "// Auto-generated self-contained header check\n#include <${rel_hdr}>\n")
    list(APPEND HEADER_CHECK_SRCS "${gen_cc}")
    math(EXPR idx "${idx} + 1")
  endforeach()

  add_library(theta_header_check OBJECT EXCLUDE_FROM_ALL ${HEADER_CHECK_SRCS})
  target_include_directories(theta_header_check
                             PRIVATE "${CMAKE_CURRENT_SOURCE_DIR}/include")
endfunction()

# ------------------------------------------------------------------------------
# 1. Standard CMake & pkg-config installation helper Produces: -
#   $out/include/theta/... - $out/lib/lib... (if compiled targets) -
#   $out/lib/cmake/<pkg>/<pkg>-config.cmake -
#   $out/lib/cmake/<pkg>/<pkg>-config-version.cmake -
#   $out/lib/cmake/<pkg>/<pkg>-targets.cmake (NAMESPACE theta::) -
#   $out/lib/pkgconfig/<pkg>.pc
# ------------------------------------------------------------------------------
function(theta_install_package)
  set(options NO_HEADERS)
  set(oneValueArgs PACKAGE_NAME DESCRIPTION EXTRA_CMAKE_INCLUDE)
  set(multiValueArgs TARGETS EXTRA_CMAKE_FILES FIND_DEPENDENCIES)
  cmake_parse_arguments(THETA_PKG "${options}" "${oneValueArgs}"
                        "${multiValueArgs}" ${ARGN})

  if(NOT THETA_PKG_TARGETS)
    message(FATAL_ERROR "theta_install_package requires TARGETS")
  endif()

  if(THETA_PKG_PACKAGE_NAME)
    set(PKG_NAME "${THETA_PKG_PACKAGE_NAME}")
  else()
    set(PKG_NAME "${PROJECT_NAME}")
  endif()

  if(NOT THETA_PKG_DESCRIPTION)
    set(THETA_PKG_DESCRIPTION "${PKG_NAME} library from the theta C++ suite")
  endif()

  if(NOT PROJECT_VERSION)
    set(PKG_VERSION "0.1.0")
  else()
    set(PKG_VERSION "${PROJECT_VERSION}")
  endif()

  # Install targets
  install(
    TARGETS ${THETA_PKG_TARGETS}
    EXPORT ${PKG_NAME}Targets
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
    INCLUDES
    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")

  # Install public headers if include/ exists
  if(NOT THETA_PKG_NO_HEADERS AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/include")
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/include/"
            DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}")
  endif()

  set(CMAKE_CONFIG_INSTALL_DIR "${CMAKE_INSTALL_LIBDIR}/cmake/${PKG_NAME}")

  # Install exported targets under theta:: namespace
  install(
    EXPORT ${PKG_NAME}Targets
    FILE ${PKG_NAME}-targets.cmake
    NAMESPACE theta::
    DESTINATION "${CMAKE_CONFIG_INSTALL_DIR}")

  # Generate and install <pkg>-config.cmake
  set(FIND_DEP_LINES "")
  foreach(_dep IN LISTS THETA_PKG_FIND_DEPENDENCIES)
    string(APPEND FIND_DEP_LINES "find_dependency(${_dep})\n")
  endforeach()

  set(EXTRA_INCLUDE_LINE "")
  if(THETA_PKG_EXTRA_CMAKE_INCLUDE)
    set(EXTRA_INCLUDE_LINE
        "include(\"\${CMAKE_CURRENT_LIST_DIR}/${THETA_PKG_EXTRA_CMAKE_INCLUDE}\")"
    )
  endif()

  set(CONFIG_FILE "${CMAKE_CURRENT_BINARY_DIR}/${PKG_NAME}-config.cmake")
  file(
    WRITE "${CONFIG_FILE}"
    "include(CMakeFindDependencyMacro)
${FIND_DEP_LINES}include(\"\${CMAKE_CURRENT_LIST_DIR}/${PKG_NAME}-targets.cmake\")
${EXTRA_INCLUDE_LINE}
")

  # Generate and install <pkg>-config-version.cmake
  set(VERSION_FILE
      "${CMAKE_CURRENT_BINARY_DIR}/${PKG_NAME}-config-version.cmake")
  write_basic_package_version_file(
    "${VERSION_FILE}"
    VERSION "${PKG_VERSION}"
    COMPATIBILITY SameMajorVersion ARCH_INDEPENDENT)

  install(FILES "${CONFIG_FILE}" "${VERSION_FILE}"
                ${THETA_PKG_EXTRA_CMAKE_FILES}
          DESTINATION "${CMAKE_CONFIG_INSTALL_DIR}")

  # Generate and install pkg-config (.pc) file using CMAKE_INSTALL_FULL_*
  set(PC_LIBS "")
  foreach(tgt IN LISTS THETA_PKG_TARGETS)
    get_target_property(tgt_type ${tgt} TYPE)
    if(NOT tgt_type STREQUAL "INTERFACE_LIBRARY")
      string(APPEND PC_LIBS " -l${tgt}")
    endif()
  endforeach()

  set(PC_FILE "${CMAKE_CURRENT_BINARY_DIR}/${PKG_NAME}.pc")
  file(
    WRITE "${PC_FILE}"
    "prefix=${CMAKE_INSTALL_PREFIX}
exec_prefix=\${prefix}
libdir=${CMAKE_INSTALL_FULL_LIBDIR}
includedir=${CMAKE_INSTALL_FULL_INCLUDEDIR}

Name: ${PKG_NAME}
Description: ${THETA_PKG_DESCRIPTION}
Version: ${PKG_VERSION}
Cflags: -I\${includedir}
Libs: -L\${libdir}${PC_LIBS}
")

  install(FILES "${PC_FILE}" DESTINATION "${CMAKE_INSTALL_LIBDIR}/pkgconfig")
endfunction()
