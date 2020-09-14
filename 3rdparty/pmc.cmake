



include(ExternalProject)


ExternalProject_Add(
        ext_pmc
        PREFIX .
        GIT_REPOSITORY    https://github.com/jingnanshi/pmc.git
        CONFIGURE_COMMAND ${CMAKE_COMMAND} -G ${CMAKE_GENERATOR} ..
        BUILD_COMMAND     ${CMAKE_COMMAND} --build ..
        INSTALL_COMMAND   ""
        TEST_COMMAND      ""
        #        SOURCE_DIR        "${CMAKE_CURRENT_BINARY_DIR}/spectra-src"
)

ExternalProject_Get_Property(ext_pmc SOURCE_DIR)
message(STATUS "pmc source dir: ${SOURCE_DIR}")
ExternalProject_Get_Property(ext_pmc BINARY_DIR)
# By default, spectra_INCLUDE_DIRS  have trailing "/".
# The actual headers files are located in `${SOURCE_DIR}/include/`.
set(PMC_INCLUDE_DIRS ${SOURCE_DIR}/include/)