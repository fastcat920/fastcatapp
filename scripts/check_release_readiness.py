#!/usr/bin/env python3
"""Fail closed for distribution paths that currently only produce test builds."""
import os
import sys


def check(platform, environ):
    channel = environ.get("FASTCAT_BUILD_CHANNEL", "local")
    if channel not in {"local", "test", "release"}:
        raise ValueError("FASTCAT_BUILD_CHANNEL must be local, test or release")
    if platform not in {"android", "windows", "macos", "ios", "tvos", "linux"}:
        raise ValueError("Unknown packaging platform")
    if channel != "release":
        return
    if platform in {"windows", "macos", "ios", "tvos"}:
        raise ValueError(
            f"Formal {platform} releases are blocked: this workflow has no verified "
            "production signing/export pipeline. Configure and validate that pipeline "
            "before enabling release; use test only for explicitly identified test builds. "
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
