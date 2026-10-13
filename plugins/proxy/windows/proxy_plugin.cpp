#include "proxy_plugin.h"
#include "proxy_configuration.h"

// Explicit Unicode WinINet APIs preserve existing PAC and bypass values.
#include <windows.h>
#include <WinInet.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <array>
#include <memory>
#include <sstream>
#include <string>
#include <variant>

#pragma comment(lib, "wininet")

namespace {

bool WideToUtf8(const std::wstring& value, std::string& output) {
  if (value.empty()) { output.clear(); return true; }
  if (value.size() > 32767) return false;
  const int length = static_cast<int>(value.size());
  const int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
      value.data(), length, nullptr, 0, nullptr, nullptr);
  if (size <= 0) return false;
  output.resize(size);
  return WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, value.data(),
      length, output.data(), size, nullptr, nullptr) == size;
}

bool Utf8ToWide(const std::string& value, std::wstring& output) {
  if (value.empty()) { output.clear(); return true; }
  if (value.size() > 32767 || value.find('\0') != std::string::npos) return false;
  const int length = static_cast<int>(value.size());
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      value.data(), length, nullptr, 0);
  if (size <= 0) return false;
  output.resize(size);
  return MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, value.data(),
      length, output.data(), size) == size;
}

// InternetQueryOption allocates strings that must be GlobalFree'd, including
// partial results on failure. Each fallback attempt owns its own allocations.
struct QueryOptions {
  INTERNET_PER_CONN_OPTIONW values[4]{};
  ~QueryOptions() {
    for (size_t i = 1; i < 4; ++i) {
      if (values[i].Value.pszValue) GlobalFree(values[i].Value.pszValue);
    }
  }
};

bool ReadConfiguration(DWORD flagsOption, proxy::ProxyConfiguration& output) {
  QueryOptions options;
  options.values[0].dwOption = flagsOption;
  options.values[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
  options.values[2].dwOption = INTERNET_PER_CONN_PROXY_BYPASS;
  options.values[3].dwOption = INTERNET_PER_CONN_AUTOCONFIG_URL;
  INTERNET_PER_CONN_OPTION_LISTW list{};
  list.dwSize = sizeof(list);
  list.pszConnection = nullptr;  // Default LAN only; never enumerate/change RAS.
  list.dwOptionCount = 4;
  list.pOptions = options.values;
  DWORD size = sizeof(list);
  if (!InternetQueryOptionW(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION,
                            &list, &size)) return false;
  proxy::ProxyConfiguration snapshot;
  snapshot["flags"] = std::to_string(options.values[0].Value.dwValue);
  const char* keys[] = {"server", "bypass", "pacUrl"};
  for (size_t i = 1; i < 4; ++i) {
    const wchar_t* value = options.values[i].Value.pszValue;
    if (!WideToUtf8(value ? std::wstring(value) : std::wstring(),
                    snapshot[keys[i - 1]])) return false;
  }
  output = std::move(snapshot);
  return true;
}

bool ReadConfiguration(proxy::ProxyConfiguration& output) {
  // Query FLAGS_UI first as documented by Microsoft; restore via FLAGS.
  return ReadConfiguration(INTERNET_PER_CONN_FLAGS_UI, output) ||
         ReadConfiguration(INTERNET_PER_CONN_FLAGS, output);
}

bool WriteConfiguration(const proxy::ProxyConfiguration& patch) {
  if (!proxy::IsValidProxyPatch(patch)) return false;
  if (patch.empty()) return true;
  std::array<INTERNET_PER_CONN_OPTIONW, 4> options{};
  std::array<std::wstring, 4> strings;
  size_t count = 0;
  for (const auto& entry : patch) {
    auto& option = options[count];
    if (entry.first == "flags") {
      uint32_t flags = 0;
      if (!proxy::ParseProxyFlags(entry.second, flags)) return false;
      option.dwOption = INTERNET_PER_CONN_FLAGS;
      option.Value.dwValue = static_cast<DWORD>(flags);
    } else {
      if (!Utf8ToWide(entry.second, strings[count])) return false;
      option.dwOption = entry.first == "server" ? INTERNET_PER_CONN_PROXY_SERVER :
          entry.first == "bypass" ? INTERNET_PER_CONN_PROXY_BYPASS :
                                   INTERNET_PER_CONN_AUTOCONFIG_URL;
      option.Value.pszValue = const_cast<wchar_t*>(strings[count].c_str());
    }
    ++count;
  }
  INTERNET_PER_CONN_OPTION_LISTW list{};
  list.dwSize = sizeof(list);
  list.pszConnection = nullptr;
  list.dwOptionCount = static_cast<DWORD>(count);
  list.pOptions = options.data();
  if (!InternetSetOptionW(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION,
                         &list, sizeof(list))) return false;
  const bool changed = InternetSetOptionW(nullptr,
      INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0) != FALSE;
  const bool refreshed = InternetSetOptionW(nullptr,
      INTERNET_OPTION_REFRESH, nullptr, 0) != FALSE;
  // Partial write/notification failure is not success. Dart re-reads and
  // rolls back only fields it still owns using its in-memory lease.
  return changed && refreshed;
}

flutter::EncodableMap ProxyStatus() {
  proxy::ProxyConfiguration snapshot;
  const bool available = ReadConfiguration(snapshot);
  uint32_t flags = 0;
  if (available) proxy::ParseProxyFlags(snapshot["flags"], flags);
  const bool enabled = (flags & PROXY_TYPE_PROXY) != 0;
  bool consistent = available && !enabled;
  std::string host;
  int port = 0;
  if (available && !snapshot["server"].empty()) {
    std::stringstream stream(snapshot["server"]);
    std::string segment;
    bool first = true;
    consistent = true;
    while (std::getline(stream, segment, ';')) {
      const auto equals = segment.find('=');
      if (equals != std::string::npos) segment = segment.substr(equals + 1);
      const auto colon = segment.rfind(':');
      uint32_t parsedPort = 0;
      if (colon == std::string::npos || colon == 0 ||
          !proxy::ParseProxyFlags(segment.substr(colon + 1), parsedPort) ||
          parsedPort == 0 || parsedPort > 65535) {
        consistent = false;
        continue;
      }
      const auto parsedHost = segment.substr(0, colon);
      if (first) {
        host = parsedHost; port = static_cast<int>(parsedPort); first = false;
      } else if (host != parsedHost || port != static_cast<int>(parsedPort)) {
        consistent = false;
      }
    }
    if (first) consistent = false;
  }
  return {{flutter::EncodableValue("available"), flutter::EncodableValue(available)},
          {flutter::EncodableValue("enabled"), flutter::EncodableValue(enabled)},
          {flutter::EncodableValue("consistent"), flutter::EncodableValue(consistent)},
          {flutter::EncodableValue("host"), flutter::EncodableValue(host)},
          {flutter::EncodableValue("port"), flutter::EncodableValue(port)},
          {flutter::EncodableValue("source"), flutter::EncodableValue("wininet")}};
}

}  // namespace

namespace proxy {

void ProxyPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "proxy", &flutter::StandardMethodCodec::GetInstance());
  auto plugin = std::make_unique<ProxyPlugin>();
  channel->SetMethodCallHandler([pointer = plugin.get()](const auto& call, auto result) {
    pointer->HandleMethodCall(call, std::move(result));
  });
  registrar->AddPlugin(std::move(plugin));
}

ProxyPlugin::ProxyPlugin() {}
ProxyPlugin::~ProxyPlugin() {}

void ProxyPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "ReadProxyConfiguration") {
    ProxyConfiguration snapshot;
    if (!ReadConfiguration(snapshot)) {
      result->Error("proxy_read_failed", "WinINet proxy configuration could not be read.");
      return;
    }
    flutter::EncodableMap values;
    for (const auto& entry : snapshot) {
      values[flutter::EncodableValue(entry.first)] = flutter::EncodableValue(entry.second);
    }
    result->Success(flutter::EncodableValue(values));
  } else if (call.method_name() == "WriteProxyConfiguration") {
    const auto* arguments = call.arguments();
    const auto* values = arguments ? std::get_if<flutter::EncodableMap>(arguments) : nullptr;
    if (!values) { result->Success(flutter::EncodableValue(false)); return; }
    ProxyConfiguration patch;
    for (const auto& entry : *values) {
      const auto* key = std::get_if<std::string>(&entry.first);
      const auto* value = std::get_if<std::string>(&entry.second);
      if (!key || !value) { result->Success(flutter::EncodableValue(false)); return; }
      patch[*key] = *value;
    }
    result->Success(flutter::EncodableValue(WriteConfiguration(patch)));
  } else if (call.method_name() == "GetProxyStatus") {
    result->Success(flutter::EncodableValue(ProxyStatus()));
  } else {
    // Old StartProxy/StopProxy blindly rewrote RAS settings. Windows callers
    // must now use the snapshot/partial-write lease; no destructive fallback.
    result->NotImplemented();
  }
}

}  // namespace proxy
