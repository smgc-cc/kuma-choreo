#!/bin/sh

# ==============================
# 环境变量配置与默认值
# ==============================
KOMARI_SERVER="${KOMARI_SERVER:-}"
KOMARI_SECRET="${KOMARI_SECRET:-}"

# 赋予默认端口防止 JSON 语法错误
SB_PORT=${SB_PORT:-""}
SB_PASSWD=${SB_PASSWD:-""}

# 清理函数的定义
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
    
    cat <<EOF > /tmp/sing-box.json
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
    {
      "type": "trojan",
      "tag": "trojan-in",
      "listen": "127.0.0.1",
      "listen_port": ${SB_PORT},
      "sniff": true,
      "users": [{ "name": "trojan", "password": "${SB_PASSWD}" }],
      "transport": {
        "type": "ws",
        "path": "/media-cdn",
        "early_data_header_name": "Sec-WebSocket-Protocol"
      }
    }
  ],
  "outbounds": [{ "type": "direct", "tag": "direct" }],
  "experimental": { "cache_file": { "enabled": true } }
}
EOF

    echo "[sing-box] 启动..."
    # 将日志放在 /tmp 目录下，确保 10014 用户有权写入
    sing-box run -c /tmp/sing-box.json > /tmp/sing-box.log 2>&1 &
    
    sleep 1
    if ! kill -0 $! 2>/dev/null; then
        echo "[sing-box] 启动失败! 日志内容:"
        cat /app/sing-box.log
        exit 1
    fi
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
exec node server/server.js
