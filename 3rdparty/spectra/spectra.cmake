
# Spectra stands for Sparse Eigenvalue Computation Toolkit as a Redesigned ARPACK.
# It is a C++ library for large scale eigenvalue problems, built on top of Eigen, an open source linear algebra library.
# Spectra is implemented as a header-only C++ library, whose only dependency, Eigen, is also header-only.
# Hence Spectra can be easily embedded in C++ projects that require calculating eigenvalues of large matrices.


include(ExternalProject)


ExternalProject_Add(
        ext_spectra
        PREFIX spectra
        GIT_REPOSITORY    https://github.com/jingnanshi/spectra
        GIT_TAG           5c4fb1de050847988faaaaa50f60e7d3d5f16143
#        SOURCE_DIR        "${CMAKE_CURRENT_BINARY_DIR}/spectra-src"
#        BINARY_DIR        ""
        CONFIGURE_COMMAND  ${CMAKE_COMMAND} -G ${CMAKE_GENERATOR} .
        BUILD_COMMAND      ${CMAKE_COMMAND} --build .
#        INSTALL_COMMAND   ""
#        TEST_COMMAND      ""
        )

ExternalProject_Get_Property(ext_spectra SOURCE_DIR)
message(STATUS "spectra source dir: ${SOURCE_DIR}")
# By default, spectra_INCLUDE_DIRS  have trailing "/".
# The actual headers files are located in `${SOURCE_DIR}/include/`.
set(SPECTRA_INCLUDE_DIRS ${SOURCE_DIR}/include/)
