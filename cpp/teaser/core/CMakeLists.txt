
set(CORE_SRC
        graph.cc
        certification.cc
        registration.cc

        )

set(ALL_CORE_SRC
        ${CORE_SRC}
        )

# Create object library
add_library(core OBJECT ${ALL_CORE_SRC})
teaser_set_global_properties(core)
teaser_link_3rdparty_libraries(core)
teaser_set_teaser_lib_properties(core)
teaser_show_and_abort_on_warning(core)