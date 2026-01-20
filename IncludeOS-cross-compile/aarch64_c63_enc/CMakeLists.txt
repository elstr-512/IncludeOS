cmake_minimum_required(VERSION 3.31.6)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

project(hello_includeos)


### ~ VIDEOS
set(YUV_VIDEO foreman.yuv)
set(VIDEO_SRC ${CMAKE_CURRENT_SOURCE_DIR}/videos-yuv/${YUV_VIDEO})
set(EMBEDDED_FILE ${VIDEO_SRC} CACHE PATH "Path to the file to embed (optional)")
### ~

find_package(IncludeOS)

include(os)

os_add_executable(hello_includeos "Hello world - OS included" src/main.cpp)

### ~ VIDEOS
if (EMBEDDED_FILE)
  file(SIZE ${EMBEDDED_FILE} EMBEDDED_FILE_SIZE)

  file(GENERATE OUTPUT ${CMAKE_BINARY_DIR}/empty.c CONTENT "")
  set_source_files_properties(${CMAKE_BINARY_DIR}/empty.c PROPERTIES GENERATED TRUE)
  add_library(empty OBJECT ${CMAKE_BINARY_DIR}/empty.c)

  add_custom_command(OUTPUT payload.o
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    COMMAND ${CMAKE_OBJCOPY}
    --add-section=.videos=${EMBEDDED_FILE}
    --set-section-flags=.videos=contents,alloc,load,readonly,data
    --add-symbol=__binary_yuv_start=.videos:0
    --add-symbol=__binary_yuv_end=.videos:${EMBEDDED_FILE_SIZE}
    $<TARGET_OBJECTS:empty> payload.o
    DEPENDS empty
  )

  set_source_files_properties(payload.o PROPERTIES GENERATED TRUE)
  target_sources(${PROJECT_NAME}.elf.bin PRIVATE payload.o)
endif ()
### ~

if("${ARCH}" STREQUAL "aarch64")
  os_add_drivers(hello_includeos boot_logger)
  os_add_stdout(hello_includeos default_stdout)

else()
  os_add_drivers(hello_includeos virtionet vmxnet3 boot_logger)
  os_add_stdout(hello_includeos default_stdout)

endif()

# This would be for application specific libs.
#os_link_libraries(hello_includeos PRIVATE your_custom_lib)


# TODO: remove or hide the ELF_POSTFIX.
# currently os.cmake expects the target name to be TARGET.elf.bin
# where TARGET is the first param to os_add_executable.
# I added it here becuase nix expects an install target.
set(BINARY_NAME hello_includeos)
set(ELF_TARGET ${BINARY_NAME}${ELF_POSTFIX})

install(TARGETS ${ELF_TARGET} DESTINATION bin)
