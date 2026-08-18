#!/usr/bin/env bash

set -Eeuo pipefail

# FastCat 设备管理网关一键部署脚本。
#
# 服务器使用方式：
#   cd /www/wwwroot/get.fastcat.com
#   sudo ./deploy-device-gateway.sh
#
# 默认从 GitHub main 分支稀疏拉取 device_gateway 目录。需要临时指定
# 其他分支时，可使用 DEPLOY_BRANCH=分支名，但生产环境建议保持 main。

EXPECTED_DIR="/www/wwwroot/get.fastcat.com"
DEPLOY_DIR="$(pwd -P)"

if [ "$DEPLOY_DIR" != "$EXPECTED_DIR" ]; then
  echo "错误：请先进入 $EXPECTED_DIR 再执行本脚本"
  echo "当前目录：$DEPLOY_DIR"
  exit 1
fi

SOURCE_DIR="$DEPLOY_DIR/gateway-source"
BACKUP_ROOT="$DEPLOY_DIR/backups"
RELEASE_ID="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$BACKUP_ROOT/device-gateway-$RELEASE_ID"
BRANCH="${DEPLOY_BRANCH:-main}"
REPOSITORY_URL="${DEPLOY_REPOSITORY_URL:-git@github.com:fastcat920/fastcatapp.git}"
SERVICE_NAME="device-gateway"
NEW_BINARY="$DEPLOY_DIR/device_gateway.new"
LIVE_BINARY="$DEPLOY_DIR/device_gateway"
HEALTH_URL="${DEPLOY_HEALTH_URL:-http://127.0.0.1:8787/healthz}"
SSH_KEY="${DEPLOY_GIT_SSH_KEY:-/root/.ssh/id_ed25519}"
ROLLBACK_REQUIRED=false

cleanup() {
  rm -f "$NEW_BINARY"
}

wait_for_health() {
  local attempt
  for attempt in 1 2 3 4 5; do
    if systemctl is-active --quiet "$SERVICE_NAME" && \
      curl \
        --fail \
        --silent \
        --show-error \
        --max-time 5 \
        "$HEALTH_URL" \
        >/dev/null; then
      return 0
    fi
    sleep 2
  done
  return 1
}

rollback() {
  local reason="$1"

  trap - ERR INT TERM
  set +e
  ROLLBACK_REQUIRED=false

  echo
  echo "========== 部署失败，开始自动回滚 =========="
  echo "失败原因：$reason"
  echo
  echo "新版本最近日志："
  journalctl -u "$SERVICE_NAME" -n 100 --no-pager || true

  systemctl stop "$SERVICE_NAME" || true

  if [ ! -f "$BACKUP_DIR/device_gateway" ]; then
    echo "严重错误：没有找到回滚程序：$BACKUP_DIR/device_gateway"
    exit 1
  fi

  cp -a "$BACKUP_DIR/device_gateway" "$LIVE_BINARY"
  chmod 755 "$LIVE_BINARY"

  if ! systemctl start "$SERVICE_NAME"; then
    echo "严重错误：旧版本恢复后仍无法启动，请立即人工检查"
    systemctl status "$SERVICE_NAME" --no-pager || true
    exit 1
  fi

  if wait_for_health; then
    echo "回滚成功，旧版本已恢复运行"
  else
    echo "严重错误：旧版本已恢复，但健康检查仍未通过，请立即人工检查"
    systemctl status "$SERVICE_NAME" --no-pager || true
    exit 1
  fi

  echo "已恢复备份：$BACKUP_DIR"
  exit 1
}

on_error() {
  local exit_code="$1"
  local line_number="$2"

  if [ "$ROLLBACK_REQUIRED" = "true" ]; then
    rollback "脚本第 $line_number 行执行失败（退出码 $exit_code）"
  fi

  echo "错误：脚本第 $line_number 行执行失败（退出码 $exit_code）"
  exit "$exit_code"
}

on_signal() {
  if [ "$ROLLBACK_REQUIRED" = "true" ]; then
    rollback "部署过程被中断"
  fi
  echo "部署已取消，线上程序未被替换"
  exit 130
}

trap cleanup EXIT
trap 'on_error $? $LINENO' ERR
trap on_signal INT TERM

if command -v flock >/dev/null 2>&1; then
  exec 9>"$DEPLOY_DIR/.device-gateway-deploy.lock"
  if ! flock -n 9; then
    echo "错误：已有另一个设备网关部署任务正在运行"
    exit 1
  fi
fi

echo "========================================"
echo "设备管理后端更新"
echo "部署目录：$DEPLOY_DIR"
echo "源码分支：$BRANCH"
echo "备份目录：$BACKUP_DIR"
echo "========================================"

echo
echo "========== 1. 检查环境 =========="

git --version
go version
curl --version | sed -n '1p'

if [ ! -f "$LIVE_BINARY" ]; then
  echo "错误：没有找到线上程序：$LIVE_BINARY"
  exit 1
fi

if [ ! -f "$DEPLOY_DIR/.env" ]; then
  echo "错误：没有找到配置文件：$DEPLOY_DIR/.env"
  exit 1
fi

if ! systemctl cat "$SERVICE_NAME" >/dev/null 2>&1; then
  echo "错误：没有找到 systemd 服务：$SERVICE_NAME"
  exit 1
fi

if [ -f "$SSH_KEY" ]; then
  export GIT_SSH_COMMAND="ssh -i $SSH_KEY -o IdentitiesOnly=yes"
elif [[ "$REPOSITORY_URL" == git@* ]]; then
  echo "错误：SSH 仓库需要私钥，但没有找到：$SSH_KEY"
  exit 1
fi

echo
echo "========== 2. 创建独立备份 =========="

mkdir -p "$BACKUP_DIR"
cp -a "$LIVE_BINARY" "$BACKUP_DIR/device_gateway"
cp -a "$DEPLOY_DIR/.env" "$BACKUP_DIR/.env"

if [ -d "$DEPLOY_DIR/data" ]; then
  cp -a "$DEPLOY_DIR/data" "$BACKUP_DIR/data"
fi

if [ -f "/etc/systemd/system/device-gateway.service" ]; then
  cp -a \
    "/etc/systemd/system/device-gateway.service" \
    "$BACKUP_DIR/device-gateway.service"
fi

printf "%s\n" \
  "backup_time=$RELEASE_ID" \
  "branch=$BRANCH" \
  "deploy_dir=$DEPLOY_DIR" \
  >"$BACKUP_DIR/backup-info.txt"

ln -sfn "$BACKUP_DIR" "$BACKUP_ROOT/latest"
echo "文件备份完成：$BACKUP_DIR"

echo
echo "========== 3. 可选备份 PostgreSQL =========="

POSTGRES_DSN="$(
  set -a
  # shellcheck disable=SC1091
  source "$DEPLOY_DIR/.env"
  printf '%s' "${DG_POSTGRES_DSN:-}"
)"

if [ -n "$POSTGRES_DSN" ]; then
  if command -v pg_dump >/dev/null 2>&1; then
    pg_dump \
      "$POSTGRES_DSN" \
      --format=custom \
      --file="$BACKUP_DIR/device-gateway-postgres.dump"
    echo "PostgreSQL 备份完成"
  else
    echo "警告：配置了 DG_POSTGRES_DSN，但没有安装 pg_dump"
    echo "本次继续部署，但 PostgreSQL 没有包含在备份中"
  fi
else
  echo "未配置 DG_POSTGRES_DSN，跳过 PostgreSQL 备份"
fi

echo
echo "========== 4. 稀疏拉取设备管理后端源码 =========="

if [ ! -d "$SOURCE_DIR/.git" ]; then
  echo "首次创建源码目录：$SOURCE_DIR"
  git clone \
    --filter=blob:none \
    --depth=1 \
    --no-checkout \
    --single-branch \
    --branch "$BRANCH" \
    "$REPOSITORY_URL" \
    "$SOURCE_DIR"
fi

cd "$SOURCE_DIR"

if [ -n "$(git status --porcelain)" ]; then
  echo "错误：源码目录存在未提交改动，请先处理：$SOURCE_DIR"
  git status --short
  exit 1
fi

git config core.sparseCheckout true
printf "/device_gateway/\n" >"$SOURCE_DIR/.git/info/sparse-checkout"

# 显式更新远程引用，使过去用 --single-branch 克隆其他分支的目录也能
# 无损切换到 main，而不依赖旧的 remote.origin.fetch 配置。
git fetch \
  --depth=1 \
  origin \
  "+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH"

git checkout -B "$BRANCH" "origin/$BRANCH"

echo
echo "当前源码版本："
git log -1 --oneline

if [ ! -f "$SOURCE_DIR/device_gateway/go.mod" ]; then
  echo "错误：没有检出 device_gateway/go.mod"
  exit 1
fi

echo
echo "========== 5. 下载依赖并测试 =========="

cd "$SOURCE_DIR/device_gateway"
go mod download
go test ./...
go vet ./...

echo
echo "========== 6. 构建 Linux AMD64 后端 =========="

CGO_ENABLED=0 \
GOOS=linux \
GOARCH=amd64 \
go build \
  -trimpath \
  -ldflags="-s -w" \
  -o "$NEW_BINARY" \
  .

chmod 755 "$NEW_BINARY"

if [ ! -s "$NEW_BINARY" ]; then
  echo "错误：构建出的程序为空"
  exit 1
fi

echo "新程序信息："
ls -lh "$NEW_BINARY"
file "$NEW_BINARY"

echo
echo "========== 7. 替换程序并启动服务 =========="

# 从这里开始，任何异常或中断都会自动恢复刚才备份的旧程序并重新启动。
ROLLBACK_REQUIRED=true

systemctl stop "$SERVICE_NAME"
mv "$NEW_BINARY" "$LIVE_BINARY"
chmod 755 "$LIVE_BINARY"

if ! systemctl start "$SERVICE_NAME"; then
  rollback "新版本 systemd 服务启动失败"
fi

echo
echo "========== 8. 检测运行状态 =========="

if ! wait_for_health; then
  rollback "新版本未通过 systemd 或 HTTP 健康检查"
fi

ROLLBACK_REQUIRED=false

echo "systemd 状态：运行中"
echo "健康检查：通过（$HEALTH_URL）"

echo
echo "========== 9. 部署成功 =========="

systemctl status "$SERVICE_NAME" --no-pager

echo
echo "最近 50 条日志："
journalctl -u "$SERVICE_NAME" -n 50 --no-pager || true

echo
echo "========================================"
echo "设备管理后端部署完成"
echo "源码版本：$(git -C "$SOURCE_DIR" log -1 --oneline)"
echo "运行程序：$LIVE_BINARY"
echo "本次备份：$BACKUP_DIR"
echo "最近备份：$BACKUP_ROOT/latest"
echo "========================================"
