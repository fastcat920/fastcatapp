#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "boot_diag.h"
#include "flutter_window.h"
#include "utils.h"

namespace {

const wchar_t* LocalizedAppName() {
  const LANGID language = ::GetUserDefaultUILanguage();
  return PRIMARYLANGID(language) == LANG_CHINESE ? L"快猫" : L"FastCat";
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  BootDiagLog("wWinMain started");
  ConfigureDpiAwareness();
  BootDiagLog("DPI awareness configured");

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  HRESULT com_result = ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  BootDiagLog("CoInitializeEx result=" + std::to_string(com_result));

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(800, 600);
  BootDiagLog("FlutterWindow.Create begin");
  if (!window.Create(LocalizedAppName(), origin, size)) {
    BootDiagLog("FlutterWindow.Create failed");
    return EXIT_FAILURE;
  }
  BootDiagLog("FlutterWindow.Create success");
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
