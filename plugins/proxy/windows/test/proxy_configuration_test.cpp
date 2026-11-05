#include "../proxy_configuration.h"
#include <cassert>

// No Windows API or machine settings: safe on every development host.
int main() {
  uint32_t value = 0;
  assert(proxy::ParseProxyFlags("0", value) && value == 0);
  assert(proxy::ParseProxyFlags("3", value) && value == 3);
  assert(proxy::ParseProxyFlags("4294967295", value) && value == UINT32_MAX);
  for (const auto* input : {"", "-1", "+3", " 3", "3x", "4294967296", "999999999999"}) {
    assert(!proxy::ParseProxyFlags(input, value));
  }
  assert(proxy::IsValidProxyPatch({}));
  assert(proxy::IsValidProxyPatch({{"flags", "3"}, {"server", "127.0.0.1:7890"},
                                 {"bypass", "localhost;<local>"}, {"pacUrl", ""}}));
  assert(proxy::IsValidProxyPatch({{"pacUrl", "https://example.invalid/代理.pac"}}));
  assert(proxy::IsValidProxyPatch({{"flags", "13"}}));
  assert(!proxy::IsValidProxyPatch({{"connection", "RAS"}}));
  assert(!proxy::IsValidProxyPatch({{"server", std::string("host\0hidden", 11)}}));
  assert(!proxy::IsValidProxyPatch({{"bypass", std::string(32768, 'x')}}));
}
