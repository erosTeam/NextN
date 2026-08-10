cmake_minimum_required(VERSION 3.5.0)
project(NextNReaderEnhancement CXX)

add_library(nextn_super_resolution SHARED reader_super_resolution_napi.cpp)
target_compile_features(nextn_super_resolution PRIVATE cxx_std_17)
target_compile_options(nextn_super_resolution PRIVATE -Wall -Wextra)
target_link_libraries(
    nextn_super_resolution
    PRIVATE
    libace_napi.z.so
    libhilog_ndk.z.so
    libmindspore_lite_ndk.so)
