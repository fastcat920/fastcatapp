#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// Simulator-only implementation of the libclash C surface.
//
// The production archive is built from Go for physical iOS devices and cannot
// be linked into an iOS Simulator process. These stubs intentionally do not
// provide a working VPN; they only let the app and PacketTunnel extension link
// so UI flows can be previewed without a developer account or device build.

int ClashCore_init(const char *homeDir, const char *config) {
  (void)homeDir;
  (void)config;
  return -1;
}

void ClashCore_shutdown(void) {}

char *ClashCore_invoke(const char *method, const char *data) {
  (void)method;
  (void)data;
  return strdup("{\"error\":\"VPN is unavailable in the iOS Simulator\"}");
}

void ClashCore_free(char *ptr) {
  free(ptr);
}

void ClashCore_write_packet(const uint8_t *data, int32_t length) {
  (void)data;
  (void)length;
}

int ClashCore_get_mixed_port(void) {
  return 0;
}
