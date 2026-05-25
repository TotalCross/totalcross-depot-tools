include(FetchContent)

FetchContent_Declare(
  totalcross_sqlite3
  SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/.."
)

FetchContent_MakeAvailable(totalcross_sqlite3)

