cmake_minimum_required(VERSION 3.16)
project(nogui
    VERSION 0.3.0
    DESCRIPTION "fast and simple gui toolkit for Haxe"
    LANGUAGES C ASM)

set(CMAKE_C_STANDARD 11)
find_package(SDL3 REQUIRED)
find_package(Freetype REQUIRED)
find_package(JPEG REQUIRED)
find_package(PNG REQUIRED)

include_directories(include)
add_subdirectory(src/core)
add_subdirectory(src/async)
add_subdirectory(src/render)
add_subdirectory(src/window)

# Compile nogui shared library
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
add_library(nogui SHARED
    src/haxe/core.c
    src/haxe/async.c
    src/haxe/render.c
    src/haxe/window.c)
target_link_libraries(nogui PRIVATE nogui_core)
target_link_libraries(nogui PRIVATE nogui_render)
target_link_libraries(nogui PRIVATE nogui_window)
target_link_libraries(nogui PRIVATE 
    SDL3::SDL3
    Freetype::Freetype
    JPEG::JPEG
    PNG::PNG)
