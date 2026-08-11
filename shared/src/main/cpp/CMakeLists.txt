cmake_minimum_required(VERSION 3.5.0)
project(NextNReaderEnhancement CXX)

set(NCNN_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/third_party/ncnn/${OHOS_ARCH}")
if(NOT EXISTS "${NCNN_ROOT}/lib/libncnn.a")
    message(FATAL_ERROR "ncnn HarmonyOS library is missing for ${OHOS_ARCH}")
endif()

set(ncnn_DIR "${NCNN_ROOT}/lib/cmake/ncnn")
find_package(ncnn REQUIRED)

add_library(nextn_super_resolution SHARED reader_super_resolution_napi.cpp)
target_compile_features(nextn_super_resolution PRIVATE cxx_std_17)
target_compile_options(nextn_super_resolution PRIVATE -Wall -Wextra)
target_include_directories(nextn_super_resolution PRIVATE "${NCNN_ROOT}/include/ncnn")
target_link_libraries(
    nextn_super_resolution
    PRIVATE
    ncnn
    libace_napi.z.so
    libhilog_ndk.z.so
    libimage_source.so
    libpixelmap.so
    libmindspore_lite_ndk.so)
