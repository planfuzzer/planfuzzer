cmake_minimum_required(VERSION 3.10)
project(planFuzzer)

set(BUILD_SHARED_LIBS ON)

# set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O3")

find_package(PkgConfig)
find_package(PostgreSQL REQUIRED)
find_package(yaml-cpp REQUIRED)

# add_subdirectory(third_party/abseil-cpp)

include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/AFLplusplus/include
    ${CMAKE_CURRENT_SOURCE_DIR}/src/include/
    ${YAML_INCLUDE_DIRS}
    /home/.stack/programs/x86_64-linux/ghc-8.2.2/lib/ghc-8.2.2/include
)

# postgresql client
add_library(postgresql_client OBJECT
    ${CMAKE_CURRENT_SOURCE_DIR}/src/postgresql/client_postgresql.cc
)
target_include_directories(postgresql_client PUBLIC
    ${PostgreSQL_INCLUDE_DIRS}
)
target_link_libraries(postgresql_client PUBLIC
    ${PostgreSQL_LIBRARIES}
    ${YAML_CPP_LIBRARIES}
    # absl::strings absl::str_format
)
target_compile_options(postgresql_client PRIVATE -fPIC)
list(APPEND LINK_CLIENT postgresql_client)


# all client
add_library(all_client SHARED 
    ${CMAKE_CURRENT_SOURCE_DIR}/src/postgresql/client.cc
)
target_link_libraries(all_client PUBLIC 
    ${LINK_CLIENT}
)


# db driver
add_executable(db_driver 
    ${CMAKE_CURRENT_SOURCE_DIR}/src/db_driver.cc
)
target_link_libraries(db_driver 
    ${CMAKE_CURRENT_SOURCE_DIR}/src/cuckoo/libpgcuckoo.so
    ${YAML_CPP_LIBRARIES} 
    all_client
    # absl::strings absl::str_format
)
# test
add_executable(test
    ${CMAKE_CURRENT_SOURCE_DIR}/src/postgresql/test_client.cc
)
target_link_libraries(test
    ${CMAKE_CURRENT_SOURCE_DIR}/src/cuckoo/libpgcuckoo.so
    ${YAML_CPP_LIBRARIES} 
    all_client
    /usr/lib/gcc/x86_64-linux-gnu/7/libstdc++fs.a
    # absl::strings absl::str_format
)
