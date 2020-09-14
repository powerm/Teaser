# 1.
cmake_minimum_required(VERSION 3.12.0)


set (CMAKE_OSX_DEPLOYMENT_TARGET "10.9" CACHE STRING "Minimum OS X deployment version")

# 2.
# Teaser build options
option(BUILD_SHARED_LIBS          "Build shared libraries"                       OFF)
option(BUILD_EXAMPLES             "Build Open3D examples programs"               ON )
option(BUILD_UNIT_TESTS             "Build tests"                                ON )
option(BUILD_TEASER_FPFH "Build TEASER++ wrappers for PCL FPFH estimation."      OFF)
#option(BUILD_MATLAB_BINDINGS "Build MATLAB bindings" OFF)
option(BUILD_PYTHON_BINDINGS        "Build Python bindings"                      ON )
option(BUILD_PYTHON_MODULE        "Build the python module"                      ON )
#option(BUILD_DOC "Build documentation" ON)
#option(BUILD_WITH_MARCH_NATIVE "Build with flag march=native" OFF)
#option(ENABLE_MKL "Try to use Eigen with MKL" OFF)
option(WITH_OPENMP                  "Use OpenMP multi-threading"                 OFF)
option(ENABLE_DIAGNOSTIC_PRINT      "Enable printing of diagnostic messages"     ON )
# 3rd-party build options
option(USE_SYSTEM_EIGEN3          "Use system pre-installed eigen3"              OFF)
option(USE_SYSTEM_GOOGLETEST      "Use system pre-installed googletest"          OFF)
option(USE_SYSTEM_PYBIND11        "Use system pre-installed pybind11"            OFF)
option(USE_SYSTEM_SPECTRA         "Use system pre-installed spectra"             OFF)
option(USE_SYSTEM_PMC             "Use system pre-installed pmc"                 OFF)

# In ExternalProject_Add, if THIRD_PARTY_DOWNLOAD_DIR is specified, CMake will
# first try to look for the required files in THIRD_PARTY_DOWNLOAD_DIR, before
# downloading it from the internet. The files inside THIRD_PARTY_DOWNLOAD_DIR
# are prepared manually by the user. This is only supported by limited 3rd party
# libraries.
if(THIRD_PARTY_DOWNLOAD_DIR)
    message(STATUS "THIRD_PARTY_DOWNLOAD_DIR is set to ${THIRD_PARTY_DOWNLOAD_DIR}.")
else()
    message(STATUS "THIRD_PARTY_DOWNLOAD_DIR is not specified, will download directly.")
endif()

# 3
# Default build type
if(NOT CMAKE_BUILD_TYPE)
    message(STATUS "No CMAKE_BUILD_TYPE specified, default to RelWithDebInfo")
    set(CMAKE_BUILD_TYPE "RelWithDebInfo")
endif()

# Parse Teaser version number
file(STRINGS "cpp/teaser/version.txt" TEASER_VERSION_READ)
foreach(ver ${TEASER_VERSION_READ})
    if (ver MATCHES "TEASER_VERSION_(MAJOR|MINOR|PATCH|TWEAK) +([^ ]+)$")
        set(TEASER_VERSION_${CMAKE_MATCH_1} "${CMAKE_MATCH_2}" CACHE INTERNAL "")
    endif()
endforeach()
string(CONCAT TEASER_VERSION
        "${TEASER_VERSION_MAJOR}"
        ".${TEASER_VERSION_MINOR}"
        ".${TEASER_VERSION_PATCH}"
        ".${TEASER_VERSION_TWEAK}"
        )

# project property
project(Teaser VERSION ${TEASER_VERSION} LANGUAGES C CXX)
message(STATUS "Teaser ${PROJECT_VERSION}")

# CMake modules
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${PROJECT_SOURCE_DIR}/3rdparty/CMake)

# setup PYTHON_EXECUTABLE if not set
find_package(PythonExecutable REQUIRED) # invokes the module in 3rdparty/CMake

# npm version has to be MAJOR.MINOR.PATCH
string(CONCAT PROJECT_VERSION_THREE_NUMBER "${TEASER_VERSION_MAJOR}"
        ".${TEASER_VERSION_MINOR}"
        ".${TEASER_VERSION_PATCH}")

# PyPI package name controls specifies the repository name on PyPI. The default
# name is "teaser".
if(NOT DEFINED PYPI_PACKAGE_NAME)
    set(PYPI_PACKAGE_NAME "teaser")
endif()

# Set installation paths
if(UNIX OR CYGWIN)
    include(GNUInstallDirs)
    set(Teaser_INSTALL_INCLUDE_DIR "${CMAKE_INSTALL_INCLUDEDIR}")
    set(Teaser_INSTALL_BIN_DIR "${CMAKE_INSTALL_BINDIR}")
    set(Teaser_INSTALL_LIB_DIR "${CMAKE_INSTALL_LIBDIR}")
    set(Teaser_INSTALL_CMAKE_DIR "${CMAKE_INSTALL_LIBDIR}/cmake/${PROJECT_NAME}")
else()
    set(Teaser_INSTALL_INCLUDE_DIR include)
    set(Teaser_INSTALL_BIN_DIR bin)
    set(Teaser_INSTALL_LIB_DIR lib)
    set(Teaser_INSTALL_CMAKE_DIR CMake)
endif()

# Put build results in some predictable places
# The $<CONFIG> generator expression makes sure that XCode or Visual Studio do not
# append additional path components, as we need to know *exactly* where the build results
# end up.
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib/$<CONFIG>)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/lib/$<CONFIG>)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PROJECT_BINARY_DIR}/bin)

# OS specific settings
if(WIN32)
    # Windows defaults to hidden symbol visibility, override that
    # TODO: It would be better to explictly export symbols.
    #       Then, we could use -fvisibility=hidden for Linux as well
    SET(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)
    if(MSVC)
        # Make sure we don't hit the 65535 object member limit with MSVC
        #
        # /bigobj allows object files with more than 65535 members
        # /Ob2 enables function inlining, because MSVC is particularly
        # verbose with inline members
        #
        # See: https://github.com/tensorflow/tensorflow/pull/10962
        add_compile_options(/bigobj /Ob2)
    endif()
    if (STATIC_WINDOWS_RUNTIME)
        # This needs cmake_policy(SET CMP0091 NEW)
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    endif()
endif()

# Folder view for project files
set_property(GLOBAL PROPERTY USE_FOLDERS ON)

# Convenience function to link against all third-party libraries
# We need this because we create a lot of object libraries to assemble
# the main Teaser library
function(teaser_link_3rdparty_libraries target)
    target_link_libraries(${target} PRIVATE ${Teaser_3RDPARTY_PRIVATE_TARGETS})
    target_link_libraries(${target} PUBLIC ${Teaser_3RDPARTY_PUBLIC_TARGETS})
    foreach(dep IN LISTS Teaser_3RDPARTY_HEADER_TARGETS)
        if(TARGET ${dep})
            get_property(inc TARGET ${dep} PROPERTY INTERFACE_INCLUDE_DIRECTORIES)
            if(inc)
                set_property(TARGET ${target} APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${inc})
            endif()
            get_property(inc TARGET ${dep} PROPERTY INTERFACE_SYSTEM_INCLUDE_DIRECTORIES)
            if(inc)
                set_property(TARGET ${target} APPEND PROPERTY INTERFACE_SYSTEM_INCLUDE_DIRECTORIES ${inc})
            endif()
            get_property(def TARGET ${dep} PROPERTY INTERFACE_COMPILE_DEFINITIONS)
            if(def)
                set_property(TARGET ${target} APPEND PROPERTY INTERFACE_COMPILE_DEFINITIONS ${def})
            endif()
        endif()
    endforeach()
endfunction()

# Check if the compiler defines the _GLIBCXX_USE_CXX11_ABI macro
include(CheckCXXSourceCompiles)
check_cxx_source_compiles("#include <cxxabi.h>
int main() { return _GLIBCXX_USE_CXX11_ABI; }" HAS_GLIBCXX_USE_CXX11_ABI)

function(teaser_set_global_properties target)
    # Libraries need to be compiled with position independent code
    get_target_property(target_type ${target} TYPE)
    if (NOT target_type STREQUAL "EXECUTABLE")
        set_target_properties(${target} PROPERTIES POSITION_INDEPENDENT_CODE ON)
    endif()
    # Tell CMake we want a compiler that supports C++14 features
    target_compile_features(${target} PUBLIC
            cxx_variadic_templates
            cxx_constexpr
            cxx_override
            cxx_static_assert
            cxx_trailing_return_types
            cxx_return_type_deduction
            )
    target_include_directories(${target} PUBLIC
            $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/cpp>
            $<INSTALL_INTERFACE:${Teaser_INSTALL_INCLUDE_DIR}>
            )
    if(BUILD_CUDA_MODULE)
        target_compile_definitions(${target} PRIVATE BUILD_CUDA_MODULE)
        if(BUILD_CACHED_CUDA_MANAGER)
            target_compile_definitions(${target} PRIVATE BUILD_CACHED_CUDA_MANAGER)
        endif()
    endif()
    if(GLIBCXX_USE_CXX11_ABI)
        target_compile_definitions(${target} PUBLIC _GLIBCXX_USE_CXX11_ABI=1)
    else()
        target_compile_definitions(${target} PUBLIC _GLIBCXX_USE_CXX11_ABI=0)
    endif()
    if(WIN32)
        target_compile_definitions(${target} PRIVATE
                WINDOWS
                _CRT_SECURE_NO_DEPRECATE
                _CRT_NONSTDC_NO_DEPRECATE
                _SCL_SECURE_NO_WARNINGS
                )
        if(MSVC)
            target_compile_definitions(${target} PRIVATE NOMINMAX _USE_MATH_DEFINES _ENABLE_EXTENDED_ALIGNED_STORAGE)
            target_compile_options(${target} PRIVATE /EHsc /wd4522 /wd4190 /wd4819 /Wv:18 /WX)
            # Multi-thread compile, two ways to enable
            # Option 1, at build time: cmake --build . --parallel %NUMBER_OF_PROCESSORS%
            # https://stackoverflow.com/questions/36633074/set-the-number-of-threads-in-a-cmake-build
            # Option 2, at configure time: add /MP flag, no need to use Option 1
            # https://docs.microsoft.com/en-us/cpp/build/reference/mp-build-with-multiple-processes?view=vs-2019
            target_compile_options(${target} PRIVATE /MP)
            if(COMMAND target_link_options) # target_link_options add in 3.13
                # The examples' .pdb files use up a lot of space and cause us to run
                # out of space on Github Actions. Compressing gives us another couple of GB.
                target_link_options(${target} PRIVATE /pdbcompress)
            endif()
        endif()
    elseif(APPLE)
        target_compile_definitions(${target} PRIVATE UNIX APPLE)
        target_compile_options(${target} PRIVATE "-Wno-deprecated-declarations")
    elseif(UNIX)
        target_compile_definitions(${target} PRIVATE UNIX)
        target_compile_options(${target} PRIVATE "-Wno-deprecated-declarations" "$<$<COMPILE_LANGUAGE:CXX>:-Wno-unused-result>")
    endif()
    # The SHELL: prefix requires CMake 3.12+
    target_compile_options(${target} PRIVATE "$<$<COMPILE_LANGUAGE:CUDA>:--expt-extended-lambda>" "$<$<COMPILE_LANGUAGE:CUDA>:SHELL:${CUDA_GENCODES}>")
endfunction()

macro(add_source_group module_name)
    file(GLOB MODULE_HEADER_FILES "${module_name}/*.h")
    source_group("Header Files\\${module_name}" FILES ${MODULE_HEADER_FILES})
    file(GLOB MODULE_SOURCE_FILES "${module_name}/*.cpp")
    source_group("Source Files\\${module_name}" FILES ${MODULE_SOURCE_FILES})
endmacro()

# Enumerate all third-party libraries which we need later
# This creates the necessary targets and sets the
# Teaser_3RDPARTY_*_TARGETS variables we use in teaser_link_3rdparty_libraries
include(3rdparty/find_dependencies.cmake)

# Teaser library
add_subdirectory(cpp)

# Examples
if(BUILD_EXAMPLES)
    add_subdirectory(examples)
endif()


##########################   有待检查  ###########
# Install CMake configuration files
install(EXPORT ${PROJECT_NAME}Targets NAMESPACE ${PROJECT_NAME}:: DESTINATION ${Teaser_INSTALL_CMAKE_DIR})
export(EXPORT ${PROJECT_NAME}Targets NAMESPACE ${PROJECT_NAME}::)





function(teaser_aligned_print first second)
    string(LENGTH "${first}" first_len)
    math(EXPR star_len "40 - ${first_len}")
    # CMake 3.15+ has string(REPEAT), but this is backwards compatible
    string(SUBSTRING "........................................" 0 ${star_len} stars)
    message(STATUS "  ${first} ${stars} ${second}")
endfunction()

message(STATUS "========================================================================")
message(STATUS "Treaser ${PROJECT_VERSION} Configuration Summary")
message(STATUS "========================================================================")
message(STATUS "Enabled Features:")
teaser_aligned_print("OpenMP" "${WITH_OPENMP}")
teaser_aligned_print("CUDA Support" "${BUILD_CUDA_MODULE}")
teaser_aligned_print("Build Shared Library" "${BUILD_SHARED_LIBS}")
if(WIN32)
    teaser_aligned_print("Use Windows Static Runtime" "${STATIC_WINDOWS_RUNTIME}")
endif()
teaser_aligned_print("Build Unit Tests" "${BUILD_UNIT_TESTS}")
teaser_aligned_print("Build Examples" "${BUILD_EXAMPLES}")
teaser_aligned_print("Build Python Module" "${BUILD_PYTHON_MODULE}")
#teaser_aligned_print("Build Benchmarks" "${BUILD_BENCHMARKS}")
if(GLIBCXX_USE_CXX11_ABI)
    set(usage "1")
else()
    set(usage "0")
endif()
teaser_aligned_print("Force GLIBCXX_USE_CXX11_ABI=" "${usage}")
message(STATUS "========================================================================")

# Eigen3
# pybind
# googletest
# spectra
# pmc (Parallel Maximum Clique)
# tinyply
# Boost 1.5.8
# PCL 1.8
set(deps
    EIGEN3
    PYBIND11
    GOOGLETEST
    SPECTRA
    PMC
)
foreach(dep IN ITEMS ${deps})
    if(${dep}_TARGET)
        if(NOT USE_SYSTEM_${dep})
            set(usage "yes (build from source)")
        else()
            set(usage "yes")
            if(${dep}_VERSION_STRING)
                set(usage "${usage} (v${${dep}_VERSION_STRING})")
            elseif(${dep}_VERSION)
                set(usage "${usage} (v${${dep}_VERSION})")
            endif()
        endif()
    else()
        set(usage "no")
    endif()
    teaser_aligned_print("${dep}" "${usage}")
endforeach()




set(CMAKE_CXX_STANDARD 14)
