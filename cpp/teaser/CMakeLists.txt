# open3d_set_open3d_lib_properties() sets properties for the Open3D lib itself.
# This should be used for all object libraries that make up the Open3D lib.
#
# In comparison, open3d_set_global_properties() sets properties for the Open3D
# lib, and targets that links to the Open3D lib, e.g pybind, unit tests, etc.
function(teaser_set_teaser_lib_properties target)
    target_compile_definitions(${target} PRIVATE TEASER_ENABLE_DLL_EXPORTS)
endfunction()

# Configure a header file to pass the version settings to the source code
configure_file("${PROJECT_SOURCE_DIR}/cpp/teaser/Teaser.h.in"
        "${PROJECT_SOURCE_DIR}/cpp/teaser/Teaser.h")
configure_file("${PROJECT_SOURCE_DIR}/cpp/teaser/TeaserConfig.h.in"
        "${PROJECT_SOURCE_DIR}/cpp/teaser/TeaserConfig.h")

# Subdirectories
add_subdirectory(core)


# Source group for Visual Studio
add_source_group(core)


# note: adding at least one real source file to any target that references
# reference: https://cmake.org/cmake/help/v3.12/command/add_library.html#object-libraries
add_library(${CMAKE_PROJECT_NAME}

        $<TARGET_OBJECTS:core>

        )
teaser_show_and_abort_on_warning(${PROJECT_NAME})
teaser_set_global_properties(${PROJECT_NAME})
teaser_set_teaser_lib_properties(${PROJECT_NAME})
teaser_link_3rdparty_libraries(${PROJECT_NAME})


add_library(${PROJECT_NAME}::${PROJECT_NAME} ALIAS ${PROJECT_NAME})

include(CMakePackageConfigHelpers)

# find_package Teaser
configure_package_config_file(TeaserConfig.cmake.in
        "${PROJECT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/TeaserConfig.cmake"
        INSTALL_DESTINATION ${Teaser_INSTALL_CMAKE_DIR}
        PATH_VARS Teaser_INSTALL_INCLUDE_DIR
        NO_CHECK_REQUIRED_COMPONENTS_MACRO
        )

# find_package Teaser Version
write_basic_package_version_file("${PROJECT_BINARY_DIR}/TeaserConfigVersion.cmake"
        VERSION ${PROJECT_VERSION}
        COMPATIBILITY ExactVersion)

# Installation
install(TARGETS ${PROJECT_NAME} EXPORT ${PROJECT_NAME}Targets
        RUNTIME DESTINATION ${Teaser_INSTALL_BIN_DIR}
        LIBRARY DESTINATION ${Teaser_INSTALL_LIB_DIR}
        ARCHIVE DESTINATION ${Teaser_INSTALL_LIB_DIR}
        )

install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        DESTINATION ${Teaser_INSTALL_INCLUDE_DIR}
        FILES_MATCHING
        PATTERN "*.h"
        PATTERN "*.cuh"
        )

# Install the TeaserConfig.cmake and TeaserConfigVersion.cmake
install(FILES
        "${PROJECT_BINARY_DIR}${CMAKE_FILES_DIRECTORY}/TeaserConfig.cmake"
        "${PROJECT_BINARY_DIR}/TeaserConfigVersion.cmake"
        DESTINATION "${Teaser_INSTALL_CMAKE_DIR}" COMPONENT dev)

# uninstall target
if(NOT TARGET uninstall)
    configure_file("${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
            "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
            IMMEDIATE @ONLY)

    add_custom_target(uninstall COMMAND ${CMAKE_COMMAND} -P
            ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)
endif()

# Export GUI_RESOURCE_FILES to parent CMake context (cpp/teaser/)
#set(GUI_RESOURCE_FILES ${GUI_RESOURCE_FILES} PARENT_SCOPE)
#set(GUI_RESOURCE_DIR ${GUI_RESOURCE_DIR} PARENT_SCOPE)
