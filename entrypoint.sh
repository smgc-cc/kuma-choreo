#!/bin/sh

# ==============================
# 0. 数据目录动态初始化 (关键修复)
# ==============================
# 既然 /app/data 是只读的，我们改用 /tmp/data
DATA_DIR="/tmp/data"
echo "[System] 正在初始化数据目录结构于 $DATA_DIR ..."

# 创建目录结构
mkdir -p "$DATA_DIR/upload" "$DATA_DIR/screenshots" "$DATA_DIR/db"

# ==============================
# 环境变量配置与默认值
# ==============================
KOMARI_SERVER="${KOMARI_SERVER:-}"
KOMARI_SECRET="${KOMARI_SECRET:-}"
SB_PORT=${SB_PORT:-""}
SB_PASSWD=${SB_PASSWD:-""}

cleanup() {
    echo "正在关闭后台进程..."
    kill $(jobs -p) 2>/dev/null
}
trap cleanup EXIT

# ==============================
# 1. 配置并启动 sing-box
# ==============================
if [ -n "$SB_PORT" ] && [ -n "$SB_PASSWD" ]; then
    echo "[sing-box] 生成配置..."
    
    # 配置文件也放在 /tmp 保证可写
    cat <<EOF > /tmp/sing-box.json
{
  "log": { "level": "info", "timestamp": true },
  "inbounds": [{
      "type": "trojan",
      "listen": "127.0.0.1",
      "listen_port": ${SB_PORT},
      "sniff": true,
      "users": [{ "password": "${SB_PASSWD}" }],
      "transport": { "type": "ws", "path": "/media-cdn" }
  }],
  "outbounds": [{ "type": "direct", "tag": "direct" }]
}
EOF
    echo "[sing-box] 启动..."
    sing-box run -c /tmp/sing-box.json > /tmp/sing-box.log 2>&1 &
else
    echo "[sing-box] 未配置，跳过。"
fi

# ==============================
# 2. 启动 komari-agent
# ==============================
if [ -n "$KOMARI_SERVER" ] && [ -n "$KOMARI_SECRET" ]; then
    echo "[Komari] 启动监控..."
    /app/komari-agent -e "$KOMARI_SERVER" -t "$KOMARI_SECRET" --disable-auto-update >/dev/null 2>&1 &
else
    echo "[Komari] 未配置，跳过。"
fi

# ==============================
# 3. 启动主应用
# ==============================
echo "[Kuma] 启动主应用..."
# 核心：告诉 Kuma 使用我们创建的可写目录
export UPTIME_KUMA_DATA_DIR="$DATA_DIR/"
exec node server/server.js
