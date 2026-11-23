"""Deterministic draft vectors. Test-only keys. Requires Python cryptography."""
import hashlib
import hmac
import json
import struct
from pathlib import Path
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey
from cryptography.hazmat.primitives.ciphers.aead import ChaCha20Poly1305


def sha(value):
    return hashlib.sha256(value).digest()


def extract(salt, value):
    return hmac.digest(salt, value, 'sha256')


def expand(prk, info, length):
    result, block = b'', b''
    for index in range(1, (length + 31) // 32 + 1):
        block = hmac.digest(prk, block + info + bytes([index]), 'sha256')
        result += block
    return result[:length]


def pub(key):
    return X25519PrivateKey.from_private_bytes(key).public_key().public_bytes_raw()


def dh(key, peer):
    from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PublicKey
    return X25519PrivateKey.from_private_bytes(key).exchange(X25519PublicKey.from_public_bytes(peer))


class Noise:
    def __init__(self, prologue, responder):
        protocol = b'Noise_IK_25519_ChaChaPoly_SHA256'
        self.h = protocol.ljust(32, b'\0') if len(protocol) <= 32 else sha(protocol)
        self.ck = self.h
        self.key = None
        self.nonce = 0
        self.mix_hash(prologue)
        self.mix_hash(responder)

    def mix_hash(self, value):
        self.h = sha(self.h + value)

    def mix_key(self, value):
        material = expand(extract(self.ck, value), b'', 64)
        self.ck, self.key = material[:32], material[32:]
        self.nonce = 0

    def crypt(self, value, decrypt=False):
        if self.key is None:
            output = value
        else:
            nonce = b'\0' * 4 + struct.pack('<Q', self.nonce)
            aead = ChaCha20Poly1305(self.key)
            output = aead.decrypt(nonce, value, self.h) if decrypt else aead.encrypt(nonce, value, self.h)
            self.nonce += 1
        self.mix_hash(value if decrypt else output)
        return output

    def split(self):
        material = expand(extract(self.ck, b''), b'', 64)
        return material[:32], material[32:]


def make_vector():
    # All four private keys are public fixtures and MUST NOT be deployed.
    si, sr, ei, er = [bytes(range(start, start + 32)) for start in (0, 32, 64, 96)]
    carrier, service, attempt = 1, bytes(range(16)), bytes(range(160, 176))
    prefix = b'FCV3' + bytes([1, carrier]) + service + attempt
    token = b'fixture-account-token-00000000001'
    client = bytes([0]) + attempt + struct.pack('>H', len(token)) + token
    client += struct.pack('>IIIHHHH', 262144, 4194304, 30000, 128, 1024, 0, 0)
    server = bytes([0]) + bytes(range(32, 48))
    server += struct.pack('>IIIHHHHI', 262144, 4194304, 30000, 128, 1024, 0, 0, 0)
    a, b = Noise(prefix, pub(sr)), Noise(prefix, pub(sr))
    a.mix_hash(pub(ei)); a.mix_key(dh(ei, pub(sr)))
    encrypted_static = a.crypt(pub(si)); a.mix_key(dh(si, pub(sr)))
    encrypted_client = a.crypt(client)
    message1 = pub(ei) + encrypted_static + encrypted_client
    b.mix_hash(message1[:32]); b.mix_key(dh(sr, message1[:32]))
    peer_static = b.crypt(message1[32:80], True); b.mix_key(dh(sr, peer_static))
    assert b.crypt(message1[80:], True) == client
    b.mix_hash(pub(er)); b.mix_key(dh(er, pub(ei))); b.mix_key(dh(er, peer_static))
    message2 = pub(er) + b.crypt(server)
    a.mix_hash(message2[:32]); a.mix_key(dh(ei, message2[:32])); a.mix_key(dh(si, message2[:32]))
    assert a.crypt(message2[32:], True) == server
    assert a.split() == b.split() and a.h == b.h
    c2s, s2c = a.split()
    # Standard carrier uses the TLS exporter; this deterministic fixture supplies 0x00..0x1f.
    binding = bytes(range(32))
    context = sha(prefix + a.h + binding)
    directions = {}
    for label, seed in [('c2s', c2s), ('s2c', s2c)]:
        secret = extract(context, seed)
        key = expand(secret, b'FCV3 key', 32)
        iv = expand(secret, b'FCV3 iv', 12)
        directions[label] = dict(secret=secret.hex(), key=key.hex(), iv=iv.hex(),
                                 next_secret=expand(secret, b'FCV3 update', 32).hex())
    # One PING frame. Frame header type,flags,stream_id,body_length.
    plain = struct.pack('>BBQI', 8, 0, 0, 8) + bytes.fromhex('0102030405060708')
    length = struct.pack('>H', len(plain) + 16)
    key, iv = bytes.fromhex(directions['c2s']['key']), bytes.fromhex(directions['c2s']['iv'])
    aad = context + b'\0' + struct.pack('>IQ', 0, 0) + length
    cipher = ChaCha20Poly1305(key).encrypt(iv, plain, aad)
    assert ChaCha20Poly1305(key).decrypt(iv, cipher, aad) == plain
    result = dict(version='0.2', suite='Noise_IK_25519_ChaChaPoly_SHA256',
                  client_static_private=si.hex(), server_static_private=sr.hex(),
                  client_ephemeral_private=ei.hex(), server_ephemeral_private=er.hex(),
                  prologue=prefix.hex(), client_payload=client.hex(), server_payload=server.hex(),
                  client_init=message1.hex(), server_accept=message2.hex(), handshake_hash=a.h.hex(),
                  split_c2s=c2s.hex(), split_s2c=s2c.hex(), carrier_binding=binding.hex(),
                  context=context.hex(), directions=directions, record_plaintext=plain.hex(),
                  record_aad=aad.hex(), record_nonce=iv.hex(), record_wire=(length+cipher).hex())
    # Separate UDP vector uses a native-carrier transcript, specified as input for this layer.
    udp_context = bytes(range(32, 64))
    secret = extract(udp_context, c2s)
    key, iv = expand(secret, b'FCV3 key', 32), expand(secret, b'FCV3 iv', 12)
    header = bytes([0x20, 0]) + bytes(range(48, 64)) + struct.pack('>IQH', 0, 0, len(plain)+16)
    aad = udp_context + b'\0' + header
    cipher = ChaCha20Poly1305(key).encrypt(iv, plain, aad)
    assert ChaCha20Poly1305(key).decrypt(iv, cipher, aad) == plain
    result['udp_layer'] = dict(context=udp_context.hex(), split_seed=c2s.hex(), secret=secret.hex(),
        key=key.hex(), iv=iv.hex(), header=header.hex(), plaintext=plain.hex(), aad=aad.hex(),
        wire=(header+cipher).hex())
    return result


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    path = Path(__file__).with_name('vectors.json')
    result = make_vector()
    if args.check:
        assert json.loads(path.read_text()) == result
        print('Noise IK round trip, key schedule, stream record and UDP vectors verified')
    else:
        path.write_text(json.dumps(result, indent=2) + '\n')
