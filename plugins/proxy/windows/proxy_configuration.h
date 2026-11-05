#ifndef FLUTTER_PLUGIN_PROXY_CONFIGURATION_H_
#define FLUTTER_PLUGIN_PROXY_CONFIGURATION_H_

#include <cstdint>
#include <limits>
#include <map>
#include <string>

namespace proxy {
using ProxyConfiguration = std::map<std::string, std::string>;

inline bool ParseProxyFlags(const std::string& text, uint32_t& flags) {
  if (text.empty() || text.size() > 10) return false;
  uint32_t value = 0;
  for (const char digit : text) {
    if (digit < '0' || digit > '9') return false;
    const auto number = static_cast<uint32_t>(digit - '0');
    if (value > ((std::numeric_limits<uint32_t>::max)() - number) / 10) return false;
    value = value * 10 + number;
  }
  flags = value;
  return true;
}

// Partial restoration must not reset fields changed by another application.
inline bool IsValidProxyPatch(const ProxyConfiguration& patch) {
  for (const auto& entry : patch) {
    if (entry.first == "flags") {
      uint32_t flags = 0;
      if (!ParseProxyFlags(entry.second, flags)) return false;
    } else if (entry.first != "server" && entry.first != "bypass" && entry.first != "pacUrl") {
      return false;
    }
    if (entry.second.size() > 32767 || entry.second.find('\0') != std::string::npos) return false;
  }
  return true;
}
}  // namespace proxy
#endif  // FLUTTER_PLUGIN_PROXY_CONFIGURATION_H_
