 # TODO: working on aarch64 port exclusively in platform/aarch64_qemu_virt
if (NOT ${ARCH} STREQUAL "aarch64")
add_subdirectory(${ARCH})
endif()
