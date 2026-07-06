cmake_minimum_required(VERSION 3.10.2)

project(xiomi_ocr_native)

set(THIRD_PARTY_DIR "${CMAKE_CURRENT_SOURCE_DIR}/third_party")
set(PaddleLite_DIR "${THIRD_PARTY_DIR}/PaddleLite")
set(OpenCV_DIR "${THIRD_PARTY_DIR}/OpenCV/opencv4.1.0/${ANDROID_ABI}/cmake")

if(NOT EXISTS "${OpenCV_DIR}/OpenCVConfig.cmake")
    add_library(xiomi_ocr SHARED dummy.cc)
    return()
endif()

include_directories(${PaddleLite_DIR}/cxx/include)
find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})

set(CMAKE_CXX_FLAGS
    "${CMAKE_CXX_FLAGS} -std=c++11 -ffast-math -Ofast -Os -DNDEBUG -fexceptions -fvisibility=hidden -fvisibility-inlines-hidden")
set(CMAKE_SHARED_LINKER_FLAGS
    "${CMAKE_SHARED_LINKER_FLAGS} -Wl,--gc-sections -Wl,-z,nocopyreloc")

add_library(
    xiomi_ocr
    SHARED
    Native.cc
    pipeline.cc
    utils.cc
    cls_process.cc
    rec_process.cc
    det_process.cc
    db_post_process.cc
    clipper.cpp)

add_library(paddle_light_api_shared SHARED IMPORTED)
set_target_properties(
    paddle_light_api_shared
    PROPERTIES IMPORTED_LOCATION
    ${PaddleLite_DIR}/cxx/libs/${ANDROID_ABI}/libpaddle_light_api_shared.so)

find_library(log-lib log)

target_link_libraries(
    xiomi_ocr
    paddle_light_api_shared
    ${OpenCV_LIBS}
    GLESv2
    EGL
    jnigraphics
    ${log-lib})
