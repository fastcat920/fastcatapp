#!/usr/bin/env python3
"""Verify the shipped desktop IPC core accepts FCN without changing system routes."""

import argparse
import json
from pathlib import Path
import socket
import subprocess
import tempfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("core", type=Path)
    parser.add_argument("--arch", choices=("arm64", "x86_64"))
    args = parser.parse_args()
    command = [str(args.core.resolve())]
    if args.arch:
        command = ["/usr/bin/arch", "-" + args.arch] + command
    capability = subprocess.run(command + ["--supports-fcn-v3"],
                                capture_output=True, text=True, timeout=20)
    assert capability.returncode == 0 and capability.stdout.strip() == "fcn-v3", capability
    with tempfile.TemporaryDirectory(prefix="fastcat-fcn-ipc-") as home:
        with socket.socket() as listener, tempfile.TemporaryFile() as log:
            listener.bind(("127.0.0.1", 0))
            listener.listen(1)
            listener.settimeout(20)
            child = subprocess.Popen(command + [str(listener.getsockname()[1])],
                                     cwd=home, stdout=log, stderr=log)
            try:
                connection, _ = listener.accept()
                with connection:
                    connection.settimeout(30)
                    with connection.makefile("rwb") as stream:
                        sequence = 0

                        def call(method, data=None):
                            nonlocal sequence
                            sequence += 1
                            request_id = str(sequence)
                            stream.write((json.dumps({"id": request_id,
                                "method": method, "data": data}) + "\n").encode())
                            stream.flush()
                            while True:
                                line = stream.readline()
                                if not line:
                                    raise RuntimeError("desktop core exited during IPC")
                                result = json.loads(line)
                                if result.get("id") == request_id:
                                    assert result["code"] == 0, result
                                    return result.get("data")

                        def setup_proxy(proxy):
                            config = {"mixed-port": 0, "external-controller": "",
                                "tun": {"enable": False}, "dns": {"enable": False},
                                "rules": ["MATCH,DIRECT"], "proxies": [proxy]}
                            return call("setupConfig", json.dumps({"config": config, "selected-map": {}}))

                        assert call("initClash", json.dumps({"home-dir": home,
                                                            "version": 1})) is True
                        for version in (1, 2):
                            for trust in ("ca", "spki"):
                                proxy = {"name": "FCN-check", "type": "fcn",
                                    "version": version, "server": "127.0.0.1",
                                    "port": 9, "sni": "node.example", "udp": True,
                                    "uuid": "1ed909de-848b-41e7-943f-0f2d49b35f3a"}
                                if trust == "spki":
                                    proxy.update({"tls-trust": "spki",
                                        "server-public-key-pins": [
                                            "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="]})
                                result = setup_proxy(proxy)
                                assert result == "", (version, trust, result)
                                proxies = call("getProxies")
                                assert proxies["FCN-check"]["type"] == f"FCN v{version}", proxies
                                if trust == "spki":
                                    proxy["server-public-key-pins"] = ["invalid"]
                                    assert setup_proxy(proxy), "bad pin accepted"
                                    assert call("getProxies")["FCN-check"]["type"] == f"FCN v{version}"
                                print(f"FCN v{version} {trust}: desktop IPC profile accepted")
                        print("Invalid pins rejected; previous profile preserved; TUN disabled")

                        # Match Catboard's type and fields for a subscribed FCN v3 node.
                        proxy = {"name": "FCN-v3-check", "type": "fcn-v3",
                            "server": "127.0.0.1", "port": 9, "sni": "node.example",
                            "uuid": "1ed909de-848b-41e7-943f-0f2d49b35f3a", "udp": True}
                        result = setup_proxy(proxy)
                        assert result == "", result
                        proxies = call("getProxies")
                        assert proxies[proxy["name"]]["type"] == "FCN v3", proxies

                        invalid_name = "FCN-v3-invalid-uuid"
                        result = setup_proxy({**proxy, "name": invalid_name, "uuid": "invalid"})
                        assert "invalid FCN v3 subscription UUID" in result, result
                        proxies = call("getProxies")
                        assert invalid_name not in proxies, proxies
                        assert proxies[proxy["name"]]["type"] == "FCN v3", proxies
                        print("FCN v3: Catboard profile accepted; invalid UUID rejected; previous profile preserved")
            finally:
                child.terminate()
                try:
                    child.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()


if __name__ == "__main__":
    main()
