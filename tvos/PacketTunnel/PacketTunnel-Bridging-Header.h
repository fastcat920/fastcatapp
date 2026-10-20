// PacketTunnel-Bridging-Header.h
// Exposes the C API from libclash.a (compiled from mihomo Go source for iOS arm64).
// This header is generated during build when running:
//   CGO_ENABLED=1 GOOS=ios GOARCH=arm64 go build -buildmode=c-archive -o libclash.a .

#ifndef PacketTunnel_Bridging_Header_h
#define PacketTunnel_Bridging_Header_h

#include <stdint.h>

/// Initialise the mihomo core.
/// @param homeDir  Path to the home directory (writable, in App Group container).
/// @param config   YAML configuration string.
/// @return 0 on success, non-zero on error.
extern int ClashCore_init(const char *homeDir, const char *config);

/// Shut down the mihomo core and release all resources.
extern void ClashCore_shutdown(void);

/// Invoke a clash action synchronously.
/// @param method  Action method name (matches Go-side dispatcher).
/// @param data    Optional JSON-encoded parameter string (may be NULL).
/// @return Heap-allocated result string; caller must pass to ClashCore_free.
extern char *ClashCore_invoke(const char *method, const char *data);

/// Free a string returned by ClashCore_invoke.
extern void ClashCore_free(char *ptr);

/// Public packetFlow bridge. Generation rejects callbacks from old tunnels.
extern unsigned long long ClashCore_start_packets(void);
extern void ClashCore_stop_packets(void);
extern int ClashCore_write_packet(unsigned long long generation, const uint8_t *data, int32_t length);
/// Blocks until a packet is ready; stop_packets unblocks it with -1.
extern int ClashCore_read_packet(unsigned long long generation, uint8_t *data, int32_t capacity);

/// Return the mixed-port that mihomo is listening on.
/// Returns 0 if the core is not yet initialised.
extern int ClashCore_get_mixed_port(void);

#endif /* PacketTunnel_Bridging_Header_h */
