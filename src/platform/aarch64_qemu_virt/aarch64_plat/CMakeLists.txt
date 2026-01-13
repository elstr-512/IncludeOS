SET(LIB_NAME aarch64_${PLATFORM})

SET(PLATFORM_OBJECTS
  asm-start.S
  asm-stop.S

  exceptions/asm-exception_vector.S
)

SET(PLATFORM_SOURCES
  exception_handling.cpp
  gic.cpp
  init_libc.cpp
  kernel_start.cpp
  os.cpp
  platform.cpp
  sanity_checks.cpp
  serial1.cpp

  exceptions/exception_entry.cpp
  exceptions/gicv3.cpp

  info/info_FP_SIMD.cpp
  info/info_mmu.cpp
  info/info_start.cpp
  info/info_uart_print.cpp
)

INCLUDE_DIRECTORIES(../aarch64_arch)

ENABLE_LANGUAGE(ASM)

SET_SOURCE_FILES_PROPERTIES(
${PLATFORM_OBJECTS} PROPERTIES COMPILE_FLAGS "-x assembler-with-cpp"
)

ADD_LIBRARY(${LIB_NAME} STATIC ${PLATFORM_OBJECTS} ${PLATFORM_SOURCES})

SET_TARGET_PROPERTIES(${LIB_NAME} PROPERTIES LINKER_LANGUAGE CXX)

SET_TARGET_PROPERTIES(${LIB_NAME}
  PROPERTIES
  ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/platform
  ARCHIVE_OUTPUT_DIRECTORY_DEBUG ${CMAKE_BINARY_DIR}/platform
  ARCHIVE_OUTPUT_DIRECTORY_RELEASE ${CMAKE_BINARY_DIR}/platform
)

INSTALL(TARGETS ${LIB_NAME} DESTINATION platform)
