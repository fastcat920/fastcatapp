import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class ApplePacketFlowPolicyTest(unittest.TestCase):
    def test_both_extensions_use_public_packet_flow_and_dual_stack_routes(self):
        for platform in ("ios", "tvos"):
            source = (ROOT / platform / "PacketTunnel/PacketTunnelProvider.swift").read_text()
            self.assertIn("packetFlow.readPackets", source)
            self.assertIn("packetFlow.writePackets", source)
            self.assertIn("NEIPv4Route.default()", source)
            self.assertIn("NEIPv6Route.default()", source)
            self.assertIn('let dnsServers = ["198.18.0.2"]', source)
            self.assertNotIn("settings.proxySettings =", source)
            self.assertNotIn('value(forKeyPath:', source)
            self.assertIn("stopPacketForwarding()", source)

    def test_both_core_builds_include_userspace_stack(self):
        for platform in ("ios", "tvos"):
            source = (ROOT / "scripts" / f"build_{platform}_core.sh").read_text()
            self.assertIn("with_gvisor", source)
            self.assertIn("APPLE_SIMULATOR", source)


if __name__ == "__main__":
    unittest.main()
