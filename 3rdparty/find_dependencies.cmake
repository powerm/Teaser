#
# Teaser 3rd party library integration
#
set(Teaser_3RDPARTY_DIR "${PROJECT_SOURCE_DIR}/3rdparty")

# EXTERNAL_MODULES
# CMake modules we depend on in our public interface. These are modules we
# need to find_package() in our CMake config script, because we will use their
# targets.
set(Teaser_3RDPARTY_EXTERNAL_MODULES)

# PUBLIC_TARGETS
# CMake targets we link against in our public interface. They are
# either locally defined and installed, or imported from an external module
# (see above).
set(Teaser_3RDPARTY_PUBLIC_TARGETS)

# HEADER_TARGETS
# CMake targets we use in our public interface, but as a special case we do not
# need to link against the library. This simplifies dependencies where we merely
# expose declared data types from other libraries in our public headers, so it
# would be overkill to require all library users to link against that dependency.
set(Teaser_3RDPARTY_HEADER_TARGETS)

# PRIVATE_TARGETS
# CMake targets for dependencies which are not exposed in the public API. This
# will probably include HEADER_TARGETS, but also anything else we use internally.
set(Teaser_3RDPARTY_PRIVATE_TARGETS)

find_package(PkgConfig QUIET)

#
# build_3rdparty_library(name ...)
#
# Builds a third-party library from source
#
# Valid options:
#    PUBLIC
#        the library belongs to the public interface and must be installed
#    HEADER
#        the library headers belong to the public interface, but the library
#        itself is linked privately
#    INCLUDE_ALL
#        install all files in the include directories. Default is *.h, *.hpp
#    DIRECTORY <dir>
#        the library sources are in the subdirectory <dir> of 3rdparty/
#    INCLUDE_DIRS <dir> [<dir> ...]
#        include headers are in the subdirectories <dir>. Trailing slashes
#        have the same meaning as with install(DIRECTORY). <dir> must be
#        relative to the library source directory.
#        If your include is "#include <x.hpp>" and the path of the file is
#        "path/to/libx/x.hpp" then you need to pass "path/to/libx/"
#        with the trailing "/". If you have "#include <libx/x.hpp>" then you
#        need to pass "path/to/libx".
#    SOURCES <src> [<src> ...]
#        the library sources. Can be omitted for header-only libraries.
#        All sources must be relative to the library source directory.
#    LIBS <target> [<target> ...]
#        extra link dependencies
#
function(build_3rdparty_library name)
    cmake_parse_arguments(arg "PUBLIC;HEADER;INCLUDE_ALL" "DIRECTORY" "INCLUDE_DIRS;SOURCES;LIBS" ${ARGN})
    if(arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Invalid syntax: build_3rdparty_library(${name} ${ARGN})")
    endif()
    if(NOT arg_DIRECTORY)
        set(arg_DIRECTORY "${name}")
    endif()
    if(arg_INCLUDE_DIRS)
        set(include_dirs)
        foreach(incl IN LISTS arg_INCLUDE_DIRS)
            list(APPEND include_dirs "${Teaser_3RDPARTY_DIR}/${arg_DIRECTORY}/${incl}")
        endforeach()
    else()
        set(include_dirs "${Teaser_3RDPARTY_DIR}/${arg_DIRECTORY}/")
    endif()
    message(STATUS "Building library ${name} from source")
    if(arg_SOURCES)
        set(sources)
        foreach(src ${arg_SOURCES})
            list(APPEND sources "${Teaser_3RDPARTY_DIR}/${arg_DIRECTORY}/${src}")
        endforeach()
        add_library(${name} STATIC ${sources})
        foreach(incl IN LISTS include_dirs)
            if (incl MATCHES "(.*)/$")
                set(incl_path ${CMAKE_MATCH_1})
            else()
                get_filename_component(incl_path "${incl}" DIRECTORY)
            endif()
            target_include_directories(${name} SYSTEM PUBLIC
                    $<BUILD_INTERFACE:${incl_path}>
                    )
        endforeach()
        target_include_directories(${name} PUBLIC
                $<INSTALL_INTERFACE:${Teaser_INSTALL_INCLUDE_DIR}/teaser/3rdparty>
                )
        teaser_set_global_properties(${name})
        set_target_properties(${name} PROPERTIES
                OUTPUT_NAME "${PROJECT_NAME}_${name}"
                )
        if(arg_LIBS)
            target_link_libraries(${name} PRIVATE ${arg_LIBS})
        endif()
    else()
        add_library(${name} INTERFACE)
        foreach(incl IN LISTS include_dirs)
            if (incl MATCHES "(.*)/$")
                set(incl_path ${CMAKE_MATCH_1})
            else()
                get_filename_component(incl_path "${incl}" DIRECTORY)
            endif()
            target_include_directories(${name} SYSTEM INTERFACE
                    $<BUILD_INTERFACE:${incl_path}>
                    )
        endforeach()
        target_include_directories(${name} INTERFACE
                $<INSTALL_INTERFACE:${Teaser_INSTALL_INCLUDE_DIR}/teaser/3rdparty>
                )
    endif()
    if(NOT BUILD_SHARED_LIBS OR arg_PUBLIC)
        install(TARGETS ${name} EXPORT ${PROJECT_NAME}Targets
                RUNTIME DESTINATION ${Teaser_INSTALL_BIN_DIR}
                ARCHIVE DESTINATION ${Teaser_INSTALL_LIB_DIR}
                LIBRARY DESTINATION ${Teaser_INSTALL_LIB_DIR}
                )
    endif()
    if(arg_PUBLIC OR arg_HEADER)
        foreach(incl IN LISTS include_dirs)
            if(arg_INCLUDE_ALL)
                install(DIRECTORY ${incl}
                        DESTINATION ${Teaser_INSTALL_INCLUDE_DIR}/teaser/3rdparty
                        )
            else()
                install(DIRECTORY ${incl}
                        DESTINATION ${Teaser_INSTALL_INCLUDE_DIR}/teaser/3rdparty
                        FILES_MATCHING
                        PATTERN "*.h"
                        PATTERN "*.hpp"
                        )
            endif()
        endforeach()
    endif()
    add_library(${PROJECT_NAME}::${name} ALIAS ${name})
endfunction()

#
# pkg_config_3rdparty_library(name ...)
#
# Creates an interface library for a pkg-config dependency.
# All arguments are passed verbatim to pkg_search_module()
#
# The function will set ${name}_FOUND to TRUE or FALSE
# indicating whether or not the library could be found.
#
function(pkg_config_3rdparty_library name)
    if(PKGCONFIG_FOUND)
        pkg_search_module(pc_${name} ${ARGN})
    endif()
    if(pc_${name}_FOUND)
        message(STATUS "Using installed third-party library ${name} ${${name_uc}_VERSION}")
        add_library(${name} INTERFACE)
        target_include_directories(${name} SYSTEM INTERFACE ${pc_${name}_INCLUDE_DIRS})
        target_link_libraries(${name} INTERFACE ${pc_${name}_LINK_LIBRARIES})
        foreach(flag IN LISTS pc_${name}_CFLAGS_OTHER)
            if(flag MATCHES "-D(.*)")
                target_compile_definitions(${name} INTERFACE ${CMAKE_MATCH_1})
            endif()
        endforeach()
        install(TARGETS ${name} EXPORT ${PROJECT_NAME}Targets)
        set(${name}_FOUND TRUE PARENT_SCOPE)
        add_library(${PROJECT_NAME}::${name} ALIAS ${name})
    else()
        message(STATUS "Unable to find installed third-party library ${name}")
        set(${name}_FOUND FALSE PARENT_SCOPE)
    endif()
endfunction()


#
# import_3rdparty_library(name ...)
#
# Imports a third-party library that has been built independently in a sub project.
#
# Valid options:
#    PUBLIC
#        the library belongs to the public interface and must be installed
#    HEADER
#        the library headers belong to the public interface and will be
#        installed, but the library is linked privately.
#    INCLUDE_DIRS
#        the temporary location where the library headers have been installed.
#        Trailing slashes have the same meaning as with install(DIRECTORY).
#        If your include is "#include <x.hpp>" and the path of the file is
#        "/path/to/libx/x.hpp" then you need to pass "/path/to/libx/"
#        with the trailing "/". If you have "#include <libx/x.hpp>" then you
#        need to pass "/path/to/libx".
#    LIBRARIES
#        the built library name(s). It is assumed that the library is static.
#        If the library is PUBLIC, it will be renamed to Teaser_${name} at
#        install time to prevent name collisions in the install space.
#    LIB_DIR
#        the temporary location of the library. Defaults to
#        CMAKE_ARCHIVE_OUTPUT_DIRECTORY.
#
function(import_3rdparty_library name)
    cmake_parse_arguments(arg "PUBLIC;HEADER" "LIB_DIR" "INCLUDE_DIRS;LIBRARIES" ${ARGN})
    if(arg_UNPARSED_ARGUMENTS)
        message(STATUS "Unparsed: ${arg_UNPARSED_ARGUMENTS}")
        message(FATAL_ERROR "Invalid syntax: import_3rdparty_library(${name} ${ARGN})")
    endif()
    if(NOT arg_LIB_DIR)
        set(arg_LIB_DIR "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}")
    endif()
    add_library(${name} INTERFACE)
    if(arg_INCLUDE_DIRS)
        foreach(incl IN LISTS arg_INCLUDE_DIRS)
            if (incl MATCHES "(.*)/$")
                set(incl_path ${CMAKE_MATCH_1})
            else()
                get_filename_component(incl_path "${incl}" DIRECTORY)
            endif()
            target_include_directories(${name} SYSTEM INTERFACE $<BUILD_INTERFACE:${incl_path}>)
            if(arg_PUBLIC OR arg_HEADER)
                install(DIRECTORY ${incl} DESTINATION ${Teaser_INSTALL_INCLUDE_DIR}/teaser/3rdparty
                        FILES_MATCHING PATTERN "*.h" PATTERN "*.hpp"
                        )
                target_include_directories(${name} INTERFACE $<INSTALL_INTERFACE:${Teaser_INSTALL_INCLUDE_DIR}/teaser/3rdparty>)
            endif()
        endforeach()
    endif()
    if(arg_LIBRARIES)
        list(LENGTH arg_LIBRARIES libcount)
        foreach(arg_LIBRARY IN LISTS arg_LIBRARIES)
            set(library_filename ${CMAKE_STATIC_LIBRARY_PREFIX}${arg_LIBRARY}${CMAKE_STATIC_LIBRARY_SUFFIX})
            if(libcount EQUAL 1)
                set(installed_library_filename ${CMAKE_STATIC_LIBRARY_PREFIX}${PROJECT_NAME}_${name}${CMAKE_STATIC_LIBRARY_SUFFIX})
            else()
                set(installed_library_filename ${CMAKE_STATIC_LIBRARY_PREFIX}${PROJECT_NAME}_${name}_${arg_LIBRARY}${CMAKE_STATIC_LIBRARY_SUFFIX})
            endif()
            target_link_libraries(${name} INTERFACE $<BUILD_INTERFACE:${arg_LIB_DIR}/${library_filename}>)
            if(NOT BUILD_SHARED_LIBS OR arg_PUBLIC)
                install(FILES ${arg_LIB_DIR}/${library_filename}
                        DESTINATION ${Teaser_INSTALL_LIB_DIR}
                        RENAME ${installed_library_filename}
                        )
                target_link_libraries(${name} INTERFACE $<INSTALL_INTERFACE:$<INSTALL_PREFIX>/${Teaser_INSTALL_LIB_DIR}/${installed_library_filename}>)
            endif()
        endforeach()
    endif()
    if(NOT BUILD_SHARED_LIBS OR arg_PUBLIC)
        install(TARGETS ${name} EXPORT ${PROJECT_NAME}Targets)
    endif()
    add_library(${PROJECT_NAME}::${name} ALIAS ${name})
endfunction()

#
# set_local_or_remote_url(url ...)
#
# If LOCAL_URL exists, set URL to LOCAL_URL, otherwise set URL to REMOTE_URLS.
# This function is needed since CMake does not allow specifying remote URL(s) if
# a local URL is specified.
#
# Valid options:
#    LOCAL_URL
#        local url to a file. Optional parameter. If the file does not exist,
#        LOCAL_URL will be ignored. If the file exists, REMOTE URLS will be
#        ignored. CMake only allows setting single LOCAL_URL for external
#        projects.
#    REMOTE_URLS
#        remote url(s) to download a file. CMake will try to download the file
#        in the specified order.
#
function(set_local_or_remote_url URL)
    cmake_parse_arguments(arg "" "LOCAL_URL" "REMOTE_URLS" ${ARGN})
    if(arg_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Invalid syntax: set_local_or_remote_url(${name} ${ARGN})")
    endif()
    if(arg_LOCAL_URL AND (EXISTS ${arg_LOCAL_URL}))
        message(STATUS "Using local url: ${arg_LOCAL_URL}")
        set(${URL} "${arg_LOCAL_URL}" PARENT_SCOPE)
    else()
        message(STATUS "Using remote url(s): ${arg_REMOTE_URLS}")
        set(${URL} "${arg_REMOTE_URLS}" PARENT_SCOPE)
    endif()
endfunction()


########################## dependencies ################
# Eigen3
# pybind
# googletest
# spectra
# pmc (Parallel Maximum Clique)
# tinyply
# Boost 1.5.8
# PCL 1.8
# MKL   module
# LAPACK  module
# Sphinx  module
# OpenMP


# OpenMP
if(WITH_OPENMP)
    if(APPLE)
        set(CMAKE_C_COMPILER "/usr/local/Cellar/llvm/10.0.1/bin/clang")
        set(CMAKE_CXX_COMPILER "/usr/local/Cellar/llvm/10.0.1/bin/clang++")
        set(OPENMP_LIBRARIES "/usr/local/Cellar/llvm/10.0.1/lib")
        set(OPENMP_INCLUDES "/usr/local/Cellar/llvm/10.0.1/include")

        if(CMAKE_C_COMPILER_ID MATCHES "Clang")
            set(OpenMP_C "${CMAKE_C_COMPILER}")
            set(OpenMP_C_FLAGS "-fopenmp=libomp -Wno-unused-command-line-argument")
            set(OpenMP_C_LIB_NAMES "libomp" "libgomp" "libiomp5")
            set(OpenMP_libomp_LIBRARY ${OpenMP_C_LIB_NAMES})
            set(OpenMP_libgomp_LIBRARY ${OpenMP_C_LIB_NAMES})
            set(OpenMP_libiomp5_LIBRARY ${OpenMP_C_LIB_NAMES})
        endif()
        if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
            set(OpenMP_CXX "${CMAKE_CXX_COMPILER}")
            set(OpenMP_CXX_FLAGS "-fopenmp=libomp -Wno-unused-command-line-argument")
            set(OpenMP_CXX_LIB_NAMES "libomp" "libgomp" "libiomp5")
            set(OpenMP_libomp_LIBRARY ${OpenMP_CXX_LIB_NAMES})
            set(OpenMP_libgomp_LIBRARY ${OpenMP_CXX_LIB_NAMES})
            set(OpenMP_libiomp5_LIBRARY ${OpenMP_CXX_LIB_NAMES})
        endif()
    endif()

    find_package(OpenMP)

    if (OPENMP_FOUND)
        if(APPLE)
            set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS}")
            set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
            # set (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${OpenMP_EXE_LINKER_FLAGS}")
        endif(APPLE)

        if(TARGET OpenMP::OpenMP_CXX)
            message(STATUS "Building with OpenMP")
            set(OPENMP_TARGET "OpenMP::OpenMP_CXX")
            list(APPEND Teaser_3RDPARTY_PRIVATE_TARGETS "${OPENMP_TARGET}")
            if(NOT BUILD_SHARED_LIBS)
                list(APPEND Teaser_3RDPARTY_EXTERNAL_MODULES "OpenMP")
            endif()
        endif()
    endif(OPENMP_FOUND)

endif(WITH_OPENMP)

# Eigen3
if(USE_SYSTEM_EIGEN3)
    find_package(Eigen3)
    if(TARGET Eigen3::Eigen)
        message(STATUS "Using installed third-party library Eigen3 ${EIGEN3_VERSION_STRING}")
        # Eigen3 is a publicly visible dependency, so add it to the list of
        # modules we need to find in the Open3D config script.
        list(APPEND Teaser_3RDPARTY_EXTERNAL_MODULES "Eigen3")
        set(EIGEN3_TARGET "Eigen3::Eigen")
    else()
        message(STATUS "Unable to find installed third-party library Eigen3")
        set(USE_SYSTEM_EIGEN3 OFF)
    endif()
endif()
if(NOT USE_SYSTEM_EIGEN3)
    build_3rdparty_library(3rdparty_eigen3 PUBLIC DIRECTORY Eigen INCLUDE_DIRS Eigen INCLUDE_ALL)
    set(EIGEN3_TARGET "3rdparty_eigen3")
endif()
list(APPEND Teaser_3RDPARTY_PUBLIC_TARGETS "${EIGEN3_TARGET}")

# Pybind11
if(USE_SYSTEM_PYBIND11)
    find_package(pybind11)
endif()
if (NOT USE_SYSTEM_PYBIND11 OR NOT TARGET pybind11::module)
    set(USE_SYSTEM_PYBIND11 OFF)
    add_subdirectory(${Teaser_3RDPARTY_DIR}/pybind11)
endif()
if(TARGET pybind11::module)
    set(PYBIND11_TARGET "pybind11::module")
endif()

# Googletest
if (BUILD_UNIT_TESTS)
    if(USE_SYSTEM_GOOGLETEST)
        find_path(gtest_INCLUDE_DIRS gtest/gtest.h)
        find_library(gtest_LIBRARY gtest)
        find_path(gmock_INCLUDE_DIRS gmock/gmock.h)
        find_library(gmock_LIBRARY gmock)
        if(gtest_INCLUDE_DIRS AND gtest_LIBRARY AND gmock_INCLUDE_DIRS AND gmock_LIBRARY)
            message(STATUS "Using installed googletest")
            add_library(3rdparty_googletest INTERFACE)
            target_include_directories(3rdparty_googletest INTERFACE ${gtest_INCLUDE_DIRS} ${gmock_INCLUDE_DIRS})
            target_link_libraries(3rdparty_googletest INTERFACE ${gtest_LIBRARY} ${gmock_LIBRARY})
            set(GOOGLETEST_TARGET "3rdparty_googletest")
        else()
            message(STATUS "Unable to find installed googletest")
            set(USE_SYSTEM_GOOGLETEST OFF)
        endif()
    endif()
    if(NOT USE_SYSTEM_GOOGLETEST)
        build_3rdparty_library(3rdparty_googletest DIRECTORY googletest
                SOURCES
                googletest/src/gtest-all.cc
                googlemock/src/gmock-all.cc
                INCLUDE_DIRS
                googletest/include/
                googletest/
                googlemock/include/
                googlemock/
                )
        set(GOOGLETEST_TARGET "3rdparty_googletest")
    endif()
endif()

# spectra
include(${Teaser_3RDPARTY_DIR}/spectra/spectra.cmake)
import_3rdparty_library(3rdparty_spectra
        INCLUDE_DIRS ${SPECTRA_INCLUDE_DIRS}
        )
set(SPECTRA_TARGET "3rdparty_spectra")
add_dependencies(3rdparty_spectra ext_spectra)
list(APPEND Teaser_3RDPARTY_PRIVATE_TARGETS "${SPECTRA_TARGET}")


# pmc (Parallel Maximum Clique)
#include(${Teaser_3RDPARTY_DIR}/pmc/pmc.cmake)
#message(STATUS "first time to call pmc")
#import_3rdparty_library(3rdparty_pmc
#        INCLUDE_DIRS ${PMC_INCLUDE_DIRS}
#        )
#set(PMC_TARGET "3rdparty_PMC")
#add_dependencies(3rdparty_pmc ext_pmc)
#list(APPEND Teaser_3RDPARTY_PRIVATE_TARGETS "${PMC_TARGET}")
add_subdirectory(${Teaser_3RDPARTY_DIR}/pmc)
if(TARGET pmc)
    set(PMC_TARGET "pmc")
endif()

# pmc (Parallel Maximum Clique)

#build_3rdparty_library(3rdparty_pmc PRIVATE DIRECTORY pmc INCLUDE_DIRS pmc INCLUDE_ALL)
#set(PMC_TARGET "3rdparty_pmc")
#list(APPEND Teaser_3RDPARTY_PRIVATE_TARGETS "${PMC_TARGET}")


if (BUILD_TEASER_FPFH)
    # Boost
    find_package(Boost 1.58 QUIET REQUIRED)

    # PCL
    find_package(PCL 1.8 QUIET REQUIRED COMPONENTS common io features kdtree)
endif ()
















