#include "proxy_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <WinInet.h>
#include <Ras.h>
#include <RasError.h>
#include <vector>
#include <iostream>

#pragma comment(lib, "wininet")
#pragma comment(lib, "Rasapi32")

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <cwchar>
#include <sstream>
#include <string>

struct ProxyStatusData {
  bool available = false;
  bool enabled = false;
  bool consistent = false;
  std::string host;
  int port = 0;
};

bool wideStringToUtf8(const std::wstring& value, std::string& output)
{
  if (value.empty()) {
    output.clear();
    return true;
  }
  const auto length = static_cast<int>(value.size());
  const auto required = WideCharToMultiByte(
      CP_UTF8,
      WC_ERR_INVALID_CHARS,
      value.data(),
      length,
      nullptr,
      0,
      nullptr,
      nullptr);
  if (required <= 0) {
    return false;
  }
  output.resize(required);
  return WideCharToMultiByte(
             CP_UTF8,
             WC_ERR_INVALID_CHARS,
             value.data(),
             length,
             output.data(),
             required,
             nullptr,
             nullptr) == required;
}

bool parseProxyEndpoint(const std::wstring& raw, std::string& host, int& port)
{
  auto value = raw;
  const auto equals = value.find(L'=');
  if (equals != std::wstring::npos) {
    value = value.substr(equals + 1);
  }
  const auto separator = value.rfind(L':');
  if (separator == std::wstring::npos) {
    return false;
  }
  try {
    if (!wideStringToUtf8(value.substr(0, separator), host)) {
      return false;
    }
    port = std::stoi(value.substr(separator + 1));
    return !host.empty() && port > 0;
  } catch (...) {
    return false;
  }
}

ProxyStatusData getProxyStatus()
{
  ProxyStatusData status;
  INTERNET_PER_CONN_OPTION_LIST list{};
  INTERNET_PER_CONN_OPTION options[2]{};
  DWORD size = sizeof(list);
  list.dwSize = sizeof(list);
  list.pszConnection = nullptr;
  list.dwOptionCount = 2;
  list.pOptions = options;
  options[0].dwOption = INTERNET_PER_CONN_FLAGS;
  options[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;

  if (!InternetQueryOption(
          nullptr,
          INTERNET_OPTION_PER_CONNECTION_OPTION,
          &list,
          &size)) {
    return status;
  }

  status.available = true;
  status.enabled =
      (options[0].Value.dwValue & PROXY_TYPE_PROXY) == PROXY_TYPE_PROXY;
  const auto proxyValue = options[1].Value.pszValue;
  if (proxyValue == nullptr || wcslen(proxyValue) == 0) {
    status.consistent = !status.enabled;
    if (proxyValue != nullptr) GlobalFree(proxyValue);
    return status;
  }

  const std::wstring raw(proxyValue);
  GlobalFree(proxyValue);
  std::wstringstream stream(raw);
  std::wstring segment;
  bool first = true;
  status.consistent = true;
  while (std::getline(stream, segment, L';')) {
    std::string host;
    int port = 0;
    if (!parseProxyEndpoint(segment, host, port)) {
      status.consistent = false;
      continue;
    }
    if (first) {
      status.host = host;
      status.port = port;
      first = false;
    } else if (status.host != host || status.port != port) {
      status.consistent = false;
    }
  }
  if (first) status.consistent = false;
  return status;
}

bool startProxy(const int port, const flutter::EncodableList& bypassDomain)
{
  INTERNET_PER_CONN_OPTION_LIST list;
  DWORD dwBufSize = sizeof(list);
  list.dwSize = sizeof(list);
  list.pszConnection = nullptr;

  auto url = "127.0.0.1:" + std::to_string(port);
  auto wUrl = std::wstring(url.begin(), url.end());
  std::wstring wBypassList;

  for (const auto& domain : bypassDomain) {
    if (!wBypassList.empty()) {
       wBypassList += L";";
    }
    const auto& domainText = std::get<std::string>(domain);
    wBypassList += std::wstring(domainText.begin(), domainText.end());
  }

  list.dwOptionCount = 3;
  INTERNET_PER_CONN_OPTION options[3];
  list.pOptions = options;

  list.pOptions[0].dwOption = INTERNET_PER_CONN_FLAGS;
  list.pOptions[0].Value.dwValue = PROXY_TYPE_DIRECT | PROXY_TYPE_PROXY;

  list.pOptions[1].dwOption = INTERNET_PER_CONN_PROXY_SERVER;
  list.pOptions[1].Value.pszValue = const_cast<LPWSTR>(wUrl.c_str());

  list.pOptions[2].dwOption = INTERNET_PER_CONN_PROXY_BYPASS;
  list.pOptions[2].Value.pszValue = const_cast<LPWSTR>(wBypassList.c_str());

  bool success = InternetSetOption(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION, &list, dwBufSize) != FALSE;

  RASENTRYNAME entry;
  entry.dwSize = sizeof(entry);
  std::vector<RASENTRYNAME> entries;
  DWORD size = sizeof(entry), count = 0;
  LPRASENTRYNAME entryAddr = &entry;
  auto ret = RasEnumEntries(nullptr, nullptr, entryAddr, &size, &count);
  if (ret == ERROR_BUFFER_TOO_SMALL)
  {
    entries.resize(count);
    for (auto& item : entries) {
      item.dwSize = sizeof(RASENTRYNAME);
    }
    entryAddr = entries.data();
    ret = RasEnumEntries(nullptr, nullptr, entryAddr, &size, &count);
  }
  if (ret == ERROR_SUCCESS)
  {
    for (DWORD i = 0; i < count; i++)
    {
      list.pszConnection = entryAddr[i].szEntryName;
      success = InternetSetOption(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION, &list, dwBufSize) != FALSE && success;
    }
  }

  success = InternetSetOption(nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0) != FALSE && success;
  success = InternetSetOption(nullptr, INTERNET_OPTION_REFRESH, nullptr, 0) != FALSE && success;

  return success;
}

bool stopProxy()
{
  INTERNET_PER_CONN_OPTION_LIST list;
  DWORD dwBufSize = sizeof(list);

  list.dwSize = sizeof(list);
  list.pszConnection = nullptr;
  list.dwOptionCount = 1;
  INTERNET_PER_CONN_OPTION options[1];
  list.pOptions = options;
  list.pOptions[0].dwOption = INTERNET_PER_CONN_FLAGS;
  list.pOptions[0].Value.dwValue = PROXY_TYPE_DIRECT;

  bool success = InternetSetOption(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION, &list, dwBufSize) != FALSE;

  RASENTRYNAME entry;
  entry.dwSize = sizeof(entry);
  std::vector<RASENTRYNAME> entries;
  DWORD size = sizeof(entry), count = 0;
  LPRASENTRYNAME entryAddr = &entry;
  auto ret = RasEnumEntries(nullptr, nullptr, entryAddr, &size, &count);
  if (ret == ERROR_BUFFER_TOO_SMALL)
  {
    entries.resize(count);
    for (auto& item : entries) {
      item.dwSize = sizeof(RASENTRYNAME);
    }
    entryAddr = entries.data();
    ret = RasEnumEntries(nullptr, nullptr, entryAddr, &size, &count);
  }
  if (ret == ERROR_SUCCESS)
  {
    for (DWORD i = 0; i < count; i++)
    {
      list.pszConnection = entryAddr[i].szEntryName;
      success = InternetSetOption(nullptr, INTERNET_OPTION_PER_CONNECTION_OPTION, &list, dwBufSize) != FALSE && success;
    }
  }

  success = InternetSetOption(nullptr, INTERNET_OPTION_SETTINGS_CHANGED, nullptr, 0) != FALSE && success;
  success = InternetSetOption(nullptr, INTERNET_OPTION_REFRESH, nullptr, 0) != FALSE && success;

  return success;
}

namespace proxy
{

  // static
  void ProxyPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "proxy",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<ProxyPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result)
        {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  ProxyPlugin::ProxyPlugin() {}

  ProxyPlugin::~ProxyPlugin() {}

  void ProxyPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    if (method_call.method_name().compare("StopProxy") == 0)
    {
      result->Success(stopProxy());
    }
    else if (method_call.method_name().compare("StartProxy") == 0)
    {
      auto *arguments = std::get_if<flutter::EncodableMap>(method_call.arguments());
      auto port = std::get<int>(arguments->at(flutter::EncodableValue("port")));
      auto bypassDomain = std::get<flutter::EncodableList>(arguments->at(flutter::EncodableValue("bypassDomain")));
      result->Success(startProxy(port, bypassDomain));
    }
    else if (method_call.method_name().compare("GetProxyStatus") == 0)
    {
      const auto status = getProxyStatus();
      flutter::EncodableMap data;
      data[flutter::EncodableValue("available")] =
          flutter::EncodableValue(status.available);
      data[flutter::EncodableValue("enabled")] =
          flutter::EncodableValue(status.enabled);
      data[flutter::EncodableValue("consistent")] =
          flutter::EncodableValue(status.consistent);
      data[flutter::EncodableValue("host")] =
          flutter::EncodableValue(status.host);
      data[flutter::EncodableValue("port")] =
          flutter::EncodableValue(status.port);
      data[flutter::EncodableValue("source")] =
          flutter::EncodableValue("wininet");
      result->Success(flutter::EncodableValue(data));
    }
    else
    {
      result->NotImplemented();
    }
  }
} // namespace proxy
