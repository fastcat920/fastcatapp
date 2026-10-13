#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>

#include <memory>
#include <string>
#include <variant>

#include "proxy_plugin.h"

namespace proxy {
namespace test {
using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

TEST(ProxyPlugin, UnknownAndLegacyMutationsAreUnsupported) {
  ProxyPlugin plugin;
  for (const auto* method : {"StartProxy", "StopProxy", "unknown"}) {
    bool unsupported = false;
    plugin.HandleMethodCall(MethodCall(method, std::make_unique<EncodableValue>()),
        std::make_unique<MethodResultFunctions<>>(nullptr, nullptr,
            [&unsupported]() { unsupported = true; }));
    EXPECT_TRUE(unsupported);
  }
}

TEST(ProxyPlugin, InvalidPartialWriteDoesNotTouchSystemSettings) {
  ProxyPlugin plugin;
  EncodableMap patch{{EncodableValue("connection"), EncodableValue("RAS")}};
  bool replied = false;
  plugin.HandleMethodCall(MethodCall("WriteProxyConfiguration", std::make_unique<EncodableValue>(patch)),
      std::make_unique<MethodResultFunctions<>>(
          [&replied](const EncodableValue* result) {
            replied = true;
            EXPECT_FALSE(std::get<bool>(*result));
          }, nullptr, nullptr));
  EXPECT_TRUE(replied);
}

}  // namespace test
}  // namespace proxy
