#!/bin/bash
set -e

BINARY=/usr/bin/cc-connect
BACKUP=/usr/bin/cc-connect.bak
SERVICE=cc-connect
SRC_DIR=/home/ccbot/repos/cc-connect
BUILD_OUT=/tmp/cc-connect-new
RESTART_SCRIPT=/tmp/cc-connect-restart.sh

echo "=== cc-connect safe deploy ==="

# 1. 编译
echo "[1/4] 编译..."
cd "$SRC_DIR"
go build -o "$BUILD_OUT" ./cmd/cc-connect
chmod +x "$BUILD_OUT"
echo "  OK: $($BUILD_OUT --version 2>&1 | head -1)"

# 2. 备份
echo "[2/4] 备份当前版本..."
sudo cp "$BINARY" "$BACKUP"

# 3. 替换（先删后复制，避免 Text file busy）
echo "[3/4] 替换二进制..."
sudo rm -f "$BINARY"
sudo cp "$BUILD_OUT" "$BINARY"
rm -f "$BUILD_OUT"

# 4. 异步重启 + 健康检查（脱离当前进程，避免自杀问题）
echo "[4/4] 异步重启（3 秒后执行）..."
cat > "$RESTART_SCRIPT" << 'INNER'
#!/bin/bash
sleep 3
sudo systemctl daemon-reload
sudo systemctl restart cc-connect
sleep 10
if sudo systemctl is-active --quiet cc-connect; then
    echo "✅ 部署成功" >> /home/ccbot/.cc-connect/logs/deploy.log
else
    echo "❌ 回滚..." >> /home/ccbot/.cc-connect/logs/deploy.log
    sudo cp /usr/bin/cc-connect.bak /usr/bin/cc-connect
    sudo systemctl restart cc-connect
fi
date >> /home/ccbot/.cc-connect/logs/deploy.log
INNER
chmod +x "$RESTART_SCRIPT"
nohup bash "$RESTART_SCRIPT" > /home/ccbot/.cc-connect/logs/deploy.log 2>&1 &
echo "✅ 二进制已替换，服务将在 3 秒后重启"
