# Runs from the format target (cmake -P). cwhip-format reads .cwhip-format
# from the source directory. Files under the build directory are skipped.
if(NOT IS_DIRECTORY "${SOURCE_DIR}")
    message(FATAL_ERROR "cwhip-format: SOURCE_DIR is not a directory")
endif()
if("${BINARY_DIR}" STREQUAL "")
    message(FATAL_ERROR "cwhip-format: BINARY_DIR is not set")
endif()
cmake_path(ABSOLUTE_PATH SOURCE_DIR NORMALIZE)
cmake_path(ABSOLUTE_PATH BINARY_DIR NORMALIZE)

find_program(CWHIP_FORMAT cwhip-format NO_CACHE)
if(NOT CWHIP_FORMAT)
    message(FATAL_ERROR "cwhip-format was not found")
endif()

file(GLOB_RECURSE cw_files LIST_DIRECTORIES false "${SOURCE_DIR}/*.cw")
set(sources)
foreach(path IN LISTS cw_files)
    cmake_path(IS_PREFIX BINARY_DIR "${path}" NORMALIZE in_build)
    if(NOT in_build)
        list(APPEND sources "${path}")
    endif()
endforeach()
list(SORT sources)

if(sources)
    execute_process(
        COMMAND "${CWHIP_FORMAT}" -i ${sources}
        WORKING_DIRECTORY "${SOURCE_DIR}"
        RESULT_VARIABLE format_result)
    if(NOT format_result EQUAL 0)
        message(FATAL_ERROR "cwhip-format failed")
    endif()
endif()
