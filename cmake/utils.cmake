# --------------------------------
# print-debug
# grep: ">>> DEBUG"
# --------------------------------
# [debug_var]
function(debug_var arg1)
  message(STATUS ">>> DEBUG: ${arg1} = ${${arg1}}")
endfunction()
# [debug_msg]
function(debug_msg arg1)
  message(STATUS ">>> DEBUG: ${arg1}")
endfunction()
# --------------------------------
