include(locate-libfdt.cmake)

add_subdirectory(aarch64_arch)
add_subdirectory(aarch64_plat)

configure_file(linker.ld ${CMAKE_BINARY_DIR})
install(FILES linker.ld DESTINATION .)
