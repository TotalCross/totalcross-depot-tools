get_filename_component(TCVM_AXTLS_AUTOFETCH_DIR "${CMAKE_CURRENT_LIST_FILE}" DIRECTORY)
get_filename_component(TCVM_AXTLS_DEP_DIR "${TCVM_AXTLS_AUTOFETCH_DIR}/.." ABSOLUTE)

function(tcvm_auto_fetch_axtls)
  if(NOT DEFINED AXTLS_RELEASE_TAG)
    set(AXTLS_RELEASE_TAG "axtls-2.1.5-tc.1")
  endif()
  if(NOT DEFINED AXTLS_GITHUB_REPO)
    set(AXTLS_GITHUB_REPO "TotalCross/totalcross-depot-tools")
  endif()
  include("${TCVM_AXTLS_DEP_DIR}/cmake/FindAxTLS.cmake")
  if(AxTLS_FOUND)
    return()
  endif()
  find_program(TCVM_AXTLS_BASH bash REQUIRED)
  execute_process(
    COMMAND "${TCVM_AXTLS_BASH}" "${TCVM_AXTLS_DEP_DIR}/fetch.sh"
      --platform "${AxTLS_PLATFORM}" --arch "${AxTLS_ARCH}"
      --release-tag "${AXTLS_RELEASE_TAG}"
      --github-repo "${AXTLS_GITHUB_REPO}"
    WORKING_DIRECTORY "${TCVM_AXTLS_DEP_DIR}"
    RESULT_VARIABLE TCVM_AXTLS_FETCH_RESULT
  )
  if(NOT TCVM_AXTLS_FETCH_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to fetch axTLS prebuilt for ${AxTLS_PLATFORM}/${AxTLS_ARCH}")
  endif()
  include("${TCVM_AXTLS_DEP_DIR}/cmake/FindAxTLS.cmake")
  if(NOT AxTLS_FOUND)
    message(FATAL_ERROR "Fetched axTLS artifact was not found")
  endif()
endfunction()
