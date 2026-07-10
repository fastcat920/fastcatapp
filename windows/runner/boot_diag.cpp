#include "boot_diag.h"

#include <windows.h>

#include <sstream>
#include <string>

namespace {

std::wstring GetDiagPath() {
  wchar_t app_data[MAX_PATH];
  DWORD length = GetEnvironmentVariableW(L"APPDATA", app_data, MAX_PATH);
  std::wstring base;
  if (length > 0 && length < MAX_PATH) {
    base.assign(app_data, length);
  } else {
    wchar_t temp_path[MAX_PATH];
    DWORD temp_length = GetTempPathW(MAX_PATH, temp_path);
    if (temp_length > 0 && temp_length < MAX_PATH) {
      base.assign(temp_path, temp_length);
    } else {
      base = L".";
    }
  }

  std::wstring dir = base + L"\\FastCat";
  CreateDirectoryW(dir.c_str(), nullptr);
  return dir + L"\\boot_diag.log";
}

std::string Timestamp() {
  SYSTEMTIME time;
  GetLocalTime(&time);
  std::ostringstream stream;
  stream << time.wYear << "-";
  if (time.wMonth < 10) stream << "0";
  stream << time.wMonth << "-";
  if (time.wDay < 10) stream << "0";
  stream << time.wDay << " ";
  if (time.wHour < 10) stream << "0";
  stream << time.wHour << ":";
  if (time.wMinute < 10) stream << "0";
  stream << time.wMinute << ":";
  if (time.wSecond < 10) stream << "0";
  stream << time.wSecond << ".";
  if (time.wMilliseconds < 100) stream << "0";
  if (time.wMilliseconds < 10) stream << "0";
  stream << time.wMilliseconds;
  return stream.str();
}

}  // namespace

void BootDiagLog(const std::string& message) {
  const std::wstring path = GetDiagPath();
  HANDLE file = CreateFileW(path.c_str(), FILE_APPEND_DATA, FILE_SHARE_READ,
                            nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL,
                            nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return;
  }

  const std::string line = Timestamp() + " [native] " + message + "\r\n";
  DWORD written = 0;
  WriteFile(file, line.data(), static_cast<DWORD>(line.size()), &written,
            nullptr);
  CloseHandle(file);
}
