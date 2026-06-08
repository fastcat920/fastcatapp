#!/usr/bin/env python3
"""
XBoard 远程配置加密工具（Flux 风格 XOR+Base64）

用法：
  python encrypt_config.py                      # 加密 release_config_plaintext.json
  python encrypt_config.py decrypt              # 解密 release_config.json（验证用）
  python encrypt_config.py -i input.json        # 加密指定文件

加密结果上传到 OSS，路径填入 config.yaml 的 remote_config.sources[].url

⚠️ 注意：
  - KEY 必须与 remote_config_manager.dart 中的 _xorKey 完全一致
  - KEY 长度建议 ≥ 24 位，越长越难暴力破解
"""

import base64
import json
import sys
import os

# ─────────────────────────────────────────────────────────────
# ⚠️ 修改此密钥！同时将 remote_config_manager.dart 中的
#    _xorKey 设置为相同的值
# ─────────────────────────────────────────────────────────────
KEY = "fastcat920fastcat920"

INPUT_FILE  = "release_config_plaintext.json"
OUTPUT_FILE = "release_config.json"


def xor_encrypt(plain_text: str) -> str:
    """XOR+Base64 加密"""
    key_bytes   = KEY.encode("utf-8")
    plain_bytes = plain_text.encode("utf-8")
    encrypted   = bytearray(len(plain_bytes))
    for i, b in enumerate(plain_bytes):
        encrypted[i] = b ^ key_bytes[i % len(key_bytes)]
    return base64.b64encode(encrypted).decode("utf-8")


def xor_decrypt(encrypted_text: str) -> str:
    """XOR+Base64 解密"""
    key_bytes       = KEY.encode("utf-8")
    encrypted_bytes = base64.b64decode(encrypted_text)
    decrypted       = bytearray(len(encrypted_bytes))
    for i, b in enumerate(encrypted_bytes):
        decrypted[i] = b ^ key_bytes[i % len(key_bytes)]
    return decrypted.decode("utf-8")


def encrypt_file(input_path: str, output_path: str):
    if not os.path.exists(input_path):
        print(f"❌ 输入文件不存在: {input_path}")
        sys.exit(1)

    with open(input_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 验证是否为合法 JSON
    try:
        json.loads(content)
    except json.JSONDecodeError as e:
        print(f"❌ 输入文件不是合法 JSON: {e}")
        sys.exit(1)

    encrypted = xor_encrypt(content)

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(encrypted)

    print(f"✅ 加密完成")
    print(f"   输入: {input_path}")
    print(f"   输出: {output_path}  （上传此文件到 OSS）")
    print(f"   密钥: {KEY[:4]}{'*' * (len(KEY) - 4)}")


def decrypt_file(input_path: str):
    if not os.path.exists(input_path):
        print(f"❌ 文件不存在: {input_path}")
        sys.exit(1)

    with open(input_path, "r", encoding="utf-8") as f:
        content = f.read().strip()

    # 如果是明文 JSON，直接打印
    if content.startswith("{") or content.startswith("["):
        print("ℹ️  文件为明文 JSON，无需解密：")
        print(json.dumps(json.loads(content), ensure_ascii=False, indent=2))
        return

    try:
        decrypted = xor_decrypt(content)
        parsed    = json.loads(decrypted)
        print("✅ 解密成功：")
        print(json.dumps(parsed, ensure_ascii=False, indent=2))
    except Exception as e:
        print(f"❌ 解密失败（密钥是否匹配？）: {e}")


if __name__ == "__main__":
    args = sys.argv[1:]

    if "decrypt" in args:
        target = OUTPUT_FILE
        if "-i" in args:
            idx = args.index("-i")
            target = args[idx + 1]
        decrypt_file(target)
    else:
        src = INPUT_FILE
        if "-i" in args:
            idx = args.index("-i")
            src = args[idx + 1]
        encrypt_file(src, OUTPUT_FILE)
