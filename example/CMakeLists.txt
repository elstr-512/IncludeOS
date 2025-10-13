cmake_minimum_required(VERSION 3.6)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

project(hello_includeos)

find_package(IncludeOS)

include(os)

os_add_executable(hello_includeos "Hello world - OS included" src/main.cpp)

if("${ARCH}" STREQUAL "aarch64")
  os_add_drivers(hello_includeos boot_logger)
  os_add_stdout(hello_includeos default_stdout vga_output)
else()
  os_add_drivers(hello_includeos virtionet vmxnet3 boot_logger)
  os_add_stdout(hello_includeos default_stdout)
endif()


# This would be for application specific libs.
#os_link_libraries(hello_includeos PRIVATE your_custom_lib)

# --- aarch64 specific libs ---
# TODO: make libfdt availibe for services when calling 'include(os)'
# instead of having to link it here
if ("${ARCH}" STREQUAL "aarch64")
  find_library(FDT_LIB NAMES libfdt.a fdt REQUIRED)
  if (FDT_LIB)
    message(STATUS ">>> DEBUG: Found libfdt: ${FDT_LIB}")
    os_link_libraries(hello_includeos ${FDT_LIB})
  else()
    message(FATAL_ERROR "libfdt not found")
  endif()
endif()


# TODO: remove or hide the ELF_POSTFIX.
# currently os.cmake expects the target name to be TARGET.elf.bin
# where TARGET is the first param to os_add_executable.
# I added it here becuase nix expects an install target.
set(BINARY_NAME hello_includeos)
set(ELF_TARGET ${BINARY_NAME}${ELF_POSTFIX})

install(TARGETS ${ELF_TARGET} DESTINATION bin)
