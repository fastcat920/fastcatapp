cmake_minimum_required(VERSION 3.14)
set(PROJECT_NAME "desktop_webview_window")
project(${PROJECT_NAME} LANGUAGES CXX)

# This value is used when generating builds using this plugin, so it must
# not be changed
set(PLUGIN_NAME "desktop_webview_window_plugin")

add_library(${PLUGIN_NAME} SHARED
        "desktop_webview_window_plugin.cpp"
        "webview_window.h"
        "webview_window.cc"
        "strconv.h"
        "utils.h"
        "utils.cc"
        "flutter_view.h"
        "flutter_view.cc"
        "web_view.h"
        "web_view.cc"
        "message_channel_plugin.h"
        "message_channel_plugin.cc"
        "web_view_window_plugin.h"
        "web_view_window_plugin.cc"
        )

apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
        CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
        "${CMAKE_CURRENT_SOURCE_DIR}/include")
target_link_libraries(${PLUGIN_NAME} PRIVATE flutter flutter_wrapper_plugin flutter_wrapper_app)

add_library(Webview2 SHARED IMPORTED GLOBAL)
if(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
        set(WEBVIEW2_LOADER_DLL "${CMAKE_BINARY_DIR}/packages/Microsoft.Web.WebView2/runtimes/win-arm64/native/WebView2Loader.dll")
        set(WEBVIEW2_LOADER_LIB "${CMAKE_BINARY_DIR}/packages/Microsoft.Web.WebView2/build/native/arm64/WebView2Loader.dll.lib")
else()
        set(WEBVIEW2_LOADER_DLL "${CMAKE_CURRENT_SOURCE_DIR}/libs/x64/Webview2Loader.dll")
        set(WEBVIEW2_LOADER_LIB "${CMAKE_CURRENT_SOURCE_DIR}/libs/x64/Webview2Loader.dll.lib")
endif()

SET_PROPERTY(TARGET Webview2 PROPERTY IMPORTED_LOCATION ${WEBVIEW2_LOADER_DLL})
SET_PROPERTY(TARGET Webview2 PROPERTY IMPORTED_IMPLIB ${WEBVIEW2_LOADER_LIB})

target_link_libraries(${PLUGIN_NAME} PRIVATE Webview2 uxtheme dwmapi)

# List of absolute paths to libraries that should be bundled with the plugin
set(desktop_webview_window_bundled_libraries
        "$<TARGET_FILE:Webview2>"
        PARENT_SCOPE
        )
