#[[
 HACK: Force [dtc | libfdt] inclusion in compile_commands.json

 NOTE: This is not a build requirement, since NIX
       will locate the libraries regardless.
#]]

find_path(LIBFDT_INCLUDE_DIR libfdt.h)

if (NOT LIBFDT_INCLUDE_DIR)
  message(WARNING "libfdt.h not found — is dtc installed?")

else()
  add_compile_options(-I${LIBFDT_INCLUDE_DIR})

endif()
