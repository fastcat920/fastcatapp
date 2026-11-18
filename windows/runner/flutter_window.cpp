#include "flutter_window.h"

#include <optional>
#include <filesystem>
#include <shellapi.h>
#include <shobjidl.h>
#include <flutter/standard_method_codec.h>

#include "boot_diag.h"
#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

void FlutterWindow::UpdateSupportBadge() {
  ITaskbarList3* taskbar = nullptr;
  if (FAILED(CoCreateInstance(CLSID_TaskbarList, nullptr, CLSCTX_INPROC_SERVER,
                             IID_PPV_ARGS(&taskbar)))) return;
  if (SUCCEEDED(taskbar->HrInit())) {
    // The taskbar uses an unread marker; the tooltip carries the exact count.
    const auto label = L"FastCat support: " + std::to_wstring(support_unread_) + L" unread";
    taskbar->SetOverlayIcon(GetHandle(), support_unread_ > 0
        ? LoadIcon(nullptr, IDI_INFORMATION) : nullptr, label.c_str());
  }
  taskbar->Release();
}

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
  support_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "fastcat/support_desktop",
      &flutter::StandardMethodCodec::GetInstance());
  support_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "badge") { result->NotImplemented(); return; }
    const auto* count = call.arguments() ? std::get_if<int32_t>(call.arguments()) : nullptr;
    support_unread_ = count && *count > 0 ? *count : 0;
    UpdateSupportBadge();
    result->Success();
  });
  update_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "fastcat/update",
      &flutter::StandardMethodCodec::GetInstance());
  update_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "install") { result->NotImplemented(); return; }
        const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
        if (!args) { result->Error("INSTALL_PATH", "Invalid installer path"); return; }
        const auto entry = args->find(flutter::EncodableValue("path"));
        const auto* path = entry == args->end() ? nullptr : std::get_if<std::string>(&entry->second);
        if (!path || path->empty()) { result->Error("INSTALL_PATH", "Invalid installer path"); return; }
        const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path->c_str(), -1, nullptr, 0);
        if (!length) { result->Error("INSTALL_PATH", "Invalid installer path"); return; }
        std::wstring wide(length, L'\0');
        MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, path->c_str(), -1, wide.data(), length);
        wide.resize(length - 1);
        const std::filesystem::path installer(wide);
        std::error_code error;
        if (!installer.is_absolute() || installer.extension() != L".exe" ||
            !std::filesystem::is_regular_file(installer, error)) {
          result->Error("INSTALL_PATH", "Installer not found"); return;
        }
        SHELLEXECUTEINFOW info{};
        info.cbSize = sizeof(info);
        info.fMask = SEE_MASK_NOCLOSEPROCESS | SEE_MASK_FLAG_NO_UI;
        info.hwnd = GetHandle();
        info.lpVerb = L"open";
        info.lpFile = wide.c_str();
        info.lpParameters = L"/SILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /NORESTARTAPPLICATIONS /FASTCATUPDATE=1";
        info.nShow = SW_SHOWNORMAL;
        // ShellExecute supports the installer's requested elevation; CreateProcess
        // fails with ERROR_ELEVATION_REQUIRED instead of presenting UAC.
        if (!ShellExecuteExW(&info)) {
          result->Error(GetLastError() == ERROR_CANCELLED ? "INSTALL_CANCELLED" : "INSTALL_UNAVAILABLE",
                        "Installer was not started");
          return;
        }
        if (info.hProcess) CloseHandle(info.hProcess);
        result->Success(flutter::EncodableValue("installer_opened"));
      });

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
  support_channel_.reset();
  update_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  static const UINT taskbar_created = RegisterWindowMessage(L"TaskbarButtonCreated");
  if (message == taskbar_created) UpdateSupportBadge();
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
