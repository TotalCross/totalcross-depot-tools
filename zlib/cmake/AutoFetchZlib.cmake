include(FetchContent)

FetchContent_Declare(
  totalcross_zlib
  SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/.."
)

FetchContent_MakeAvailable(totalcross_zlib)

