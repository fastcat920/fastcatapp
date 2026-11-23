#!/usr/bin/env bash
# Import the private node issued by deploy_fastcat_v2_node.sh --direct.
set -euo pipefail
umask 077
[[ $# == 1 && -n $1 && $1 != -* ]] || { echo "用法：bash $0 root@节点服务器" >&2; exit 2; }

adb_bin=$(command -v adb || printf '%s' "${ANDROID_HOME:-$HOME/Library/Android/sdk}/platform-tools/adb")
if [[ -n ${ANDROID_SERIAL:-} ]]; then adb=("$adb_bin" -s "$ANDROID_SERIAL"); else adb=("$adb_bin" -d); fi
user=$("${adb[@]}" shell am get-current-user | tr -d '\r')
[[ $user =~ ^[0-9]+$ ]] || { echo "无法确定安卓当前用户" >&2; exit 1; }
app="run-as com.fastcat.app.debug --user $user"
"${adb[@]}" shell -T "$app id" >/dev/null

work=$(mktemp -d "${TMPDIR:-/tmp}/fastcat-direct.XXXXXXXX")
file=$work/android.json
trap 'rm -f -- "$file"; rmdir -- "$work"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
ssh_args=(-n -T)
if [[ -n ${FASTCAT_SSH_SOCKET:-} ]]; then ssh_args+=(-S "$FASTCAT_SSH_SOCKET"); fi
ssh "${ssh_args[@]}" -- "$1" 'head -c 32769 /etc/fastcat-v2-direct/android.json' > "$file"

# Only accept the schema and token format produced by our direct installer.
digest=$(python3 - "$file" <<'PY'
import hashlib, json, pathlib, re, sys
data = pathlib.Path(sys.argv[1]).read_bytes()
try:
    obj = json.loads(data)
    valid = (0 < len(data) <= 32768 and isinstance(obj, dict)
             and set(obj) == {'type','name','server','port','token','h3-port','h3-token','udp'}
             and obj['type'] == 'fastcat-auto' and obj['udp'] is True
             and isinstance(obj['name'], str) and len(obj['server']) <= 253
             and all(re.fullmatch(r'[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?', label)
                     for label in obj['server'].split('.'))
             and all(type(obj[k]) is int and 0 < obj[k] <= 65535 for k in ('port','h3-port'))
             and all(re.fullmatch(r'[0-9a-f]{64}', obj[k]) for k in ('token','h3-token')))
except (ValueError, TypeError, AttributeError, RecursionError):
    valid = False
if not valid:
    sys.exit('服务器返回的直连配置格式无效')
print(hashlib.sha256(data).hexdigest())
PY
)

# Verify the bytes the phone received before publishing under the app's filename.
write_node='set -eu
umask 077
mkdir -p cache
tmp=$(mktemp cache/.fastcat-v2-import.XXXXXXXX)
trap "rm -f -- \"$tmp\"" 0
cat > "$tmp"
actual=$(sha256sum "$tmp")
[ "${actual%% *}" = "$1" ]
mv -f "$tmp" cache/fastcat-v2-direct-import.json'
"${adb[@]}" shell -T "$app sh -c '$write_node' -- $digest" < "$file"
echo "配置已传入快猫调试版。打开或重新进入「FastCat v2 直连」即可载入。"
