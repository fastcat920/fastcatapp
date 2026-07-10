#include "flutter_window.h"

#include <optional>

#include "boot_diag.h"
#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    BootDiagLog("Win32Window::OnCreate failed");
    return false;
  }

  RECT frame = GetClientArea();
  BootDiagLog("FlutterViewController create begin");

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    BootDiagLog("FlutterViewController create failed");
    return false;
  }
  BootDiagLog("FlutterViewController create success");
  RegisterPlugins(flutter_controller_->engine());
  BootDiagLog("RegisterPlugins complete");
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  BootDiagLog("SetChildContent complete");

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    first_frame_seen_ = true;
    KillTimer(GetHandle(), kFirstFrameFallbackTimer);
    BootDiagLog("first frame callback");
    flutter_controller_->ForceRedraw();
  });
  SetTimer(GetHandle(), kFirstFrameFallbackTimer, 2000, nullptr);
  BootDiagLog("first frame callback registered");

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();
  BootDiagLog("ForceRedraw requested");

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_TIMER:
      if (wparam == kFirstFrameFallbackTimer) {
        KillTimer(hwnd, kFirstFrameFallbackTimer);
        if (!first_frame_seen_ && flutter_controller_) {
          BootDiagLog("first frame timeout, forcing redraw");
          flutter_controller_->ForceRedraw();
        }
        return 0;
      }
      break;
    case WM_SHOWWINDOW:
      if (wparam && flutter_controller_) {
        BootDiagLog("WM_SHOWWINDOW, forcing redraw");
        flutter_controller_->ForceRedraw();
      }
      break;
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
