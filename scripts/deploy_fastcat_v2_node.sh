#!/usr/bin/env bash
# First installation of the parallel FastCat v2 data node on systemd Linux.
set -euo pipefail
export LC_ALL=C
umask 077

die() { echo "安装停止：$*" >&2; exit 1; }
account=fastcat-v2
direct=false
revoke=false
case ${1:-} in
    --direct)
        shift
        [[ $# -eq 1 || $# -eq 2 ]] || die "用法：bash $0 --direct 证书域名 [端口]"
        account=fastcat-v2-direct
        direct=true
        ;;
    --revoke-direct)
        shift
        [[ $# -eq 0 ]] || die "用法：bash $0 --revoke-direct"
        account=fastcat-v2-direct
        direct=true
        revoke=true
        ;;
    *)
        [[ $# -eq 2 || $# -eq 3 ]] || die "用法：在发行目录运行 bash $0 域名 端口 [面板授权目录]，或使用 --direct 域名 [端口]"
        ;;
esac
conf=/etc/$account
lib=/usr/local/lib/$account
unitdir=/etc/systemd/system
units=("$account-h2.service" "$account-h3.service")
[[ $(uname -s) == Linux && $(uname -m) == x86_64 && $EUID == 0 ]] || die "请在 x86_64 Linux 上以 root 运行"
if "$direct"; then
    exec 9>/run/fastcat-v2-direct.lock
    flock -x 9 || die "无法锁定独立测试配置"
fi
if "$revoke"; then
    [[ -f $conf/direct-endpoint ]] || die "未找到本脚本创建的独立测试节点"
    # Re-running revoke safely finishes a partially completed operation.
    touch "$conf/revoked"
    systemctl disable --now "${units[@]}"
    rm -f -- "$conf/android.json"
    for protocol in h2 h3; do
        install -o "$account" -g "$account" -m 0600 /dev/null "$conf/$protocol.tokens"
    done
    echo "已关闭独立测试入口并撤销该手机的两份令牌。"
    exit 0
fi
domain=$1
port=${2:-18445}
host_label='[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?'
[[ ${#domain} -le 253 && $domain =~ ^${host_label}(\.${host_label})+$ ]] || die "证书域名格式错误"
[[ $port =~ ^[1-9][0-9]{0,4}$ ]] && (( port >= 1024 && port <= 65535 )) || die "端口范围为 1024 到 65535"
[[ -d /run/systemd/system ]] || die "系统未使用 systemd 管理服务"
for command in sha256sum ss systemctl systemd-analyze getent groupadd groupdel useradd userdel nologin openssl; do
    command -v "$command" >/dev/null || die "系统缺少 $command"
done
version=$(systemctl --version | awk 'NR==1 {print $2}')
[[ $version =~ ^[0-9]+$ ]] && (( version >= 247 )) || die "需要 systemd 247 或更新版本"
certdir=/etc/letsencrypt/live/$domain
[[ -s $certdir/fullchain.pem && -s $certdir/privkey.pem ]] || die "未找到 $certdir 下的 fullchain.pem 和 privkey.pem"
openssl x509 -in "$certdir/fullchain.pem" -noout -checkend 0 >/dev/null || die "证书无效或已到期"
# Certbot supplies the trust chain. Check the certificate's own hostname here
# even when the machine's CA store differs from that of the Android clients.
openssl verify -partial_chain -trusted "$certdir/fullchain.pem" -verify_hostname "$domain" "$certdir/fullchain.pem" >/dev/null || die "现有证书不匹配域名或有效期"
if [[ $# == 3 ]]; then
    [[ -n $3 && -d $3 ]] || die "授权目录不存在"
    for protocol in h2 h3; do
        file=$3/$protocol.tokens
        [[ -f $file && -r $file ]] || die "无法读取 $file"
        awk 'length<24 || length>512 || /[^!-~]/ || seen[$0]++ { exit 1 }' "$file" || die "$file 含无效或重复条目"
    done
fi

port_free() {
    local protocol bound
    for protocol in t u; do
        bound=$(ss -Han"$protocol" "sport = :$1") || die "无法查看监听端口"
        [[ -z $bound ]] || return 1
    done
}

# These fixed-purpose units have a separate Unix user, binary, credential
# lists, and service names. No mixed writes with panel-owned snapshots.
issue_direct() (
    set -eu
    local tmp tcp udp
    tmp=$(mktemp -d "$conf/.phone.XXXXXXXX")
    trap 'rm -f -- "$tmp/h2.tokens" "$tmp/h3.tokens" "$tmp/android.json"; rmdir -- "$tmp"' EXIT
    tcp=$(openssl rand -hex 32)
    udp=$(openssl rand -hex 32)
    printf '%s\n' "$tcp" > "$tmp/h2.tokens"
    printf '%s\n' "$udp" > "$tmp/h3.tokens"
    chown "$account:$account" "$tmp"/{h2,h3}.tokens
    printf '{"type":"fastcat-auto","name":"FastCat v2 Direct","server":"%s","port":%s,"token":"%s","h3-port":%s,"h3-token":"%s","udp":true}\n' \
        "$domain" "$port" "$tcp" "$port" "$udp" > "$tmp/android.json"
    for file in h2.tokens h3.tokens android.json; do mv -f -- "$tmp/$file" "$conf/$file"; done
)

wait_for_listeners() {
    local i tcp_pid udp_pid tcp udp
    for (( i=0; i<30; i++ )); do
        tcp_pid=$(systemctl show "${units[0]}" -p MainPID --value)
        udp_pid=$(systemctl show "${units[1]}" -p MainPID --value)
        tcp=$(ss -Hlntp "sport = :$port")
        udp=$(ss -Hlunp "sport = :$port")
        if [[ $tcp_pid != 0 && $udp_pid != 0 && $tcp == *"pid=$tcp_pid,"* && $udp == *"pid=$udp_pid,"* ]]; then
            return 0
        fi
        sleep 0.25
    done
    die "新服务未能同时监听。请查看 journalctl -u ${units[0]} -u ${units[1]}"
}

report_direct() {
    echo "独立测试入口 $domain TCP/UDP $port；手机配置 $conf/android.json（0600）。"
}

if "$direct" && [[ -f $conf/direct-endpoint ]]; then
    read -r installed_domain installed_port < "$conf/direct-endpoint"
    [[ $domain == "$installed_domain" && ( $# == 1 || $port == "$installed_port" ) ]] || die "该机器已有另一独立测试入口，请核对域名和端口"
    port=$installed_port
    [[ $port =~ ^[1-9][0-9]{0,4}$ ]] && (( port >= 1024 && port <= 65535 )) || die "已安装端口异常"
    if [[ -f $conf/revoked ]]; then
        systemctl stop "${units[@]}"
        port_free "$port" || die "原测试端口已被使用"
        issue_direct
        rm -- "$conf/revoked"
    fi
    [[ -s $conf/android.json && -s $conf/h2.tokens && -s $conf/h3.tokens ]] || die "原测试名单缺失，请先 --revoke-direct 再重新授权"
    systemctl start "${units[@]}"
    wait_for_listeners
    systemctl enable "${units[@]}"
    report_direct
    exit 0
fi
if "$direct" && [[ $# == 1 ]] && ! port_free "$port"; then
    port=18446
fi
# Direct mode also accepts the untouched release archive alongside this script.
if "$direct" && [[ ! -f SHA256SUMS || ! -f bin/fastcat-h2 ]]; then
    archive_dir=$(cd -- "$(dirname -- "$0")" && pwd)
    archive=FastCat-v2-Linux-amd64.tar.gz
    (cd "$archive_dir" && sha256sum -c --status "$archive.sha256") || die "请将原发行包及校验文件放在脚本旁边"
    unpack=$(mktemp -d)
    trap 'rm -rf -- "$unpack"' EXIT
    tar -xzf "$archive_dir/$archive" -C "$unpack"
    # The child reacquires the lock and uses the same explicit port.
    (cd "$unpack/FastCat-v2-Linux-amd64" && flock -u 9 && bash "$archive_dir/$(basename -- "$0")" --direct "$domain" "$port")
    exit 0
fi
[[ -f SHA256SUMS && -f bin/fastcat-h2 && -f systemd/fastcat-h2.service && -f systemd/fastcat-h3.service ]] || die "请切换到解压出的 FastCat-v2-Linux-amd64 目录"
sha256sum --check --status SHA256SUMS || die "发行目录文件校验失败"
for path in "$conf" "$lib"; do
    [[ ! -e $path && ! -L $path ]] || die "$path 已存在；首次安装不会覆盖它"
done
if getent passwd "$account" >/dev/null || getent group "$account" >/dev/null; then
    die "用户或组 $account 已存在；请核对既有安装"
fi
for unit in "${units[@]}"; do
    state=$(systemctl show "$unit" --property=LoadState --value) || [[ $state == not-found ]]
    [[ $state == not-found ]] || die "$unit 已存在或 systemd 不可用"
    for prefix in "$unitdir" /run/systemd/system /usr/lib/systemd/system /usr/local/lib/systemd/system /lib/systemd/system; do
        for path in "$prefix/$unit" "$prefix/$unit.d" "$prefix/multi-user.target.wants/$unit"; do
            [[ ! -e $path && ! -L $path ]] || die "已有服务配置 $path"
        done
    done
done
port_free "$port" || die "端口 $port 已被占用；请另选 TCP、UDP 都空闲的端口"

made_group=false
made_user=false
made_conf=false
made_lib=false
linked=()
stage=$(mktemp -d "$unitdir/.fastcat-v2.XXXXXXXX")
cleanup() {
    local rc=$?
    trap - EXIT INT TERM
    set +e
    if (( rc != 0 )); then
        for unit in "${linked[@]}"; do
            systemctl disable --now "$unit" >/dev/null 2>&1
            rm -f -- "$unitdir/$unit"
        done
        (( ${#linked[@]} == 0 )) || systemctl daemon-reload
        if "$made_lib"; then rm -f -- "$lib/fastcat-h2"; rmdir -- "$lib"; fi
        if "$made_conf"; then rm -f -- "$conf/h2.tokens" "$conf/h3.tokens"; if "$direct"; then rm -f -- "$conf/android.json" "$conf/direct-endpoint"; fi; rmdir -- "$conf"; fi
        if "$made_user"; then userdel "$account"; fi
        if "$made_group" && getent group "$account" >/dev/null; then groupdel "$account"; fi
    fi
    rm -f -- "$stage/$account"-h{2,3}.service
    rmdir -- "$stage"
    exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -m 0700 -- "$conf"; made_conf=true
mkdir -m 0755 -- "$lib"; made_lib=true
groupadd --system "$account"; made_group=true
useradd --system --gid "$account" --no-create-home --home-dir /nonexistent --shell "$(command -v nologin)" "$account"; made_user=true
chown root:"$account" "$conf"
chmod 0750 "$conf"
install -m 0755 bin/fastcat-h2 "$lib/fastcat-h2"
for protocol in h2 h3; do
    source=/dev/null
    if [[ $# == 3 ]]; then source=$3/$protocol.tokens; fi
    install -o "$account" -g "$account" -m 0600 -- "$source" "$conf/$protocol.tokens"
    unit=$account-$protocol.service
    sed -e "s|^User=fastcat-auto$|User=$account|" -e "s|^Group=fastcat-auto$|Group=$account|" \
        -e "s|/usr/local/bin/fastcat-h2 |$lib/fastcat-h2 |" -e "s|0.0.0.0:18444 |0.0.0.0:$port |" \
        -e "s|/etc/fastcat-auto/|$conf/|" -e "s|:/etc/fastcat/|:$certdir/|" \
        "systemd/fastcat-$protocol.service" > "$stage/$unit"
    chmod 0644 "$stage/$unit"
done
if "$direct"; then
    issue_direct
    printf '%s %s\n' "$domain" "$port" > "$conf/direct-endpoint"
fi
systemd-analyze verify "$stage/${units[0]}" "$stage/${units[1]}"
for unit in "${units[@]}"; do
    ln -- "$stage/$unit" "$unitdir/$unit"
    linked+=("$unit")
done
systemctl daemon-reload
systemctl start "${units[@]}"
wait_for_listeners
systemctl enable "${units[@]}"
if "$direct"; then
    report_direct
    exit 0
fi
echo "v2 已监听 $domain 的 TCP 和 UDP $port。"
if [[ ! -s $conf/h2.tokens || ! -s $conf/h3.tokens ]]; then
    echo "有入口的授权名单为空，填写面板导出的对应名单并重载服务后，该入口才能让设备连接。"
fi
