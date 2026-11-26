#!/usr/bin/env python3
"""Small TLS behavior probes against the isolated entry; no authentication."""
import json
from pathlib import Path
import socket
import subprocess
import sys
import time

config = json.loads(Path(sys.argv[1]).read_text())
host, port = config['server'].rsplit(':', 1)
rows = []
for case in ['plain-http', 'tls12-only', 'unsupported-alpn', 'no-alpn', 'valid-http1']:
    started = time.monotonic()
    row = {'case': case}
    try:
        if case == 'plain-http':
            with socket.create_connection((host, int(port)), timeout=8) as raw:
                raw.settimeout(8)
                raw.sendall(b'GET / HTTP/1.1\r\nHost: example\r\n\r\n')
                row['response_prefix'] = raw.recv(256).decode('ascii', errors='replace')
        else:
            command = ['openssl', 's_client', '-connect', config['server'],
                       '-servername', config['name'], '-verify_hostname', config['name'],
                       '-verify_return_error', '-brief', '-ign_eof',
                       '-tls1_2' if case == 'tls12-only' else '-tls1_3']
            if case == 'unsupported-alpn':
                command += ['-alpn', 'n1-diagnostic-unsupported']
            elif case != 'no-alpn':
                command += ['-alpn', 'http/1.1']
            request = 'GET / HTTP/1.1\r\nHost: '+config['name']+'\r\nConnection: close\r\n\r\n'
            result = subprocess.run(command, input=request, capture_output=True,
                                    text=True, timeout=15)
            row['exit_code'] = result.returncode
            row['established'] = 'CONNECTION ESTABLISHED' in result.stderr
            row['response_prefix'] = result.stdout.split('\n', 1)[0]
            row['diagnostics'] = [line for line in result.stderr.splitlines()
                                  if 'error:' in line or 'Protocol version:' in line
                                  or 'Verification:' in line]
    except (OSError, subprocess.TimeoutExpired) as error:
        row['error'] = str(error)
    row['elapsed_ms'] = (time.monotonic()-started)*1000
    rows.append(row)
print(json.dumps({'client': 'Mac OpenSSL CLI, not Android', 'samples': rows}, indent=2))
