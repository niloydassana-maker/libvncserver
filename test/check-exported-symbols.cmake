# Regression guard for issue #729.
#
# libvncserver bundles a private copy of the TurboJPEG API in
# src/common/turbojpeg.c. If its entry points are exported at default
# visibility, an application linking both libvncserver and libjpeg-turbo
# resolves tjCompress2 to our bundled copy instead of the one it asked for,
# which crashed reframe.
#
# The functional tests cannot catch this: everything builds and passes while
# the library advertises 12 tj* symbols. This asserts the symbol table instead.
#
# Invoked from CMakeLists.txt via add_test(). Exits non-zero if any bundled
# tj* symbol is exported.

if(NOT DEFINED SO OR NOT DEFINED READELF)
  message(FATAL_ERROR "check-exported-symbols.cmake requires -DSO= and -DREADELF=")
endif()

if(NOT EXISTS "${SO}")
  message(STATUS "SKIP: ${SO} does not exist")
  return()
endif()

execute_process(
  COMMAND "${READELF}" --dyn-syms -W "${SO}"
  OUTPUT_VARIABLE DYN_SYMS
  RESULT_VARIABLE RC
  OUTPUT_STRIP_TRAILING_WHITESPACE)

if(NOT RC EQUAL 0)
  message(STATUS "SKIP: readelf could not read ${SO}")
  return()
endif()

# FUNC, GLOBAL, defined (Ndx not UND), name begins with tj
string(REPLACE "\n" ";" LINES "${DYN_SYMS}")
set(LEAKED "")
foreach(LINE IN LISTS LINES)
  string(REGEX MATCH
    "^[ ]*[0-9]+:[ ]+[0-9a-fA-F]+[ ]+[0-9]+[ ]+FUNC[ ]+GLOBAL[ ]+[A-Z]+[ ]+[0-9]+[ ]+(tj[A-Za-z0-9_]+)$"
    MATCHED "${LINE}")
  if(CMAKE_MATCH_1)
    list(APPEND LEAKED "${CMAKE_MATCH_1}")
  endif()
endforeach()

if(LEAKED)
  list(SORT LEAKED)
  list(REMOVE_DUPLICATES LEAKED)
  string(REPLACE ";" "\n  " LEAKED_TEXT "${LEAKED}")
  message(FATAL_ERROR
    "${SO} exports bundled TurboJPEG symbols:\n  ${LEAKED_TEXT}\n\n"
    "src/common/turbojpeg.c is a private copy of the TurboJPEG API. Its symbols\n"
    "must be renamed and built hidden, or applications linking both libvncserver\n"
    "and libjpeg-turbo resolve tjCompress2 to the wrong library. See issue #729.")
endif()

message(STATUS "OK: ${SO} exports no bundled tj* symbols")