#!/usr/bin/env python3
"""Check signing requirements only for explicitly requested signed distribution."""
import os
import sys


def check(platform, environ):
    channel = environ.get("FASTCAT_BUILD_CHANNEL", "local")
    if channel not in {"local", "normal", "signed"}:
        raise ValueError("FASTCAT_BUILD_CHANNEL must be local, normal or signed")
    if platform not in {"android", "windows", "macos", "ios", "tvos", "linux"}:
        raise ValueError("Unknown packaging platform")
    if channel != "signed":
        return
    if platform in {"windows", "macos", "ios", "tvos"}:
        raise ValueError(
            f"Signed {platform} distribution is unavailable: this workflow has no verified "
            "production signing/export pipeline. Configure and validate that pipeline "
            "before selecting signed distribution; normal builds remain available. "
            "For Windows, sign the runner before calculating the Helper client hash."
        )
    if platform == "android":
        required = ("KEYSTORE_BASE64", "KEYSTORE_PASSWORD", "KEY_ALIAS", "KEY_PASSWORD")
        if any(not environ.get(key, "").strip() for key in required):
            raise ValueError("Formal Android releases require all four signing secrets; debug signing is forbidden.")


if __name__ == "__main__":
    try:
        check(sys.argv[1], os.environ)
    except (IndexError, ValueError) as error:
        sys.exit(str(error))
