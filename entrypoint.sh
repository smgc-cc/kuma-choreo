#!/bin/sh

# ==============================
# 环境变量配置与默认值
# ==============================
# Komari agent 配置
KOMARI_SERVER="${KOMARI_SERVER:-}"
KOMARI_SECRET="${KOMARI_SECRET:-}"

# Webdav 配置
WEBDAV_URL=${WEBDAV_URL:-}
WEBDAV_USER=${WEBDAV_USER:-}
WEBDAV_PASS=${WEBDAV_PASS:-}

# 备份密码（可选，留空则不加密）
BACKUP_PASS=""

# 每天备份时间（小时，0-23）
BACKUP_HOUR=4

# 保留备份天数
KEEP_DAYS=5

# 清理函数的定义
cleanup() {
    echo "正在关闭后台进程..."
    kill $(jobs -p) 2>/dev/null
}
trap cleanup EXIT

# ==============================
# 1. 启动 komari-agent
# ==============================
if [ -n "$KOMARI_SERVER" ] && [ -n "$KOMARI_SECRET" ]; then
    echo "[Komari] 启动监控..."
    /app/komari-agent -e "$KOMARI_SERVER" -t "$KOMARI_SECRET" --disable-auto-update >/dev/null 2>&1 &
else
    echo "[Komari] 未配置，跳过。"
fi

# =========================
# 2. 首次启动恢复备份
# =========================
if [ -n "$WEBDAV_URL" ] && [ ! -f "$DATA_DIR/kuma.db" ]; then
    echo "[INFO] 首次启动，检查 WebDAV 备份..."
    bash "/app/restore.sh" || echo "[WARN] 恢复失败或无备份"
fi

# =========================
# 3. 备份守护进程
# =========================
if [ -n "$WEBDAV_URL" ]; then
    (
        while true; do
            sleep 3600
            current_date=$(date +"%Y-%m-%d")
            current_hour=$(date +"%H")
            LAST_BACKUP_FILE="/tmp/last_backup_date"
            [ -f "$LAST_BACKUP_FILE" ] && last_backup_date=$(cat "$LAST_BACKUP_FILE") || last_backup_date=""
            
            if [ "$current_hour" -eq "${BACKUP_HOUR:-4}" ] && [ "$last_backup_date" != "$current_date" ]; then
                echo "[INFO] 执行每日备份..."
                bash "/app/backup.sh" && echo "$current_date" > "$LAST_BACKUP_FILE"
            fi
        done
    ) &
    echo "✓ 备份守护进程已启动 (每天 ${BACKUP_HOUR:-4}:00)"
fi

# ==============================
# 4. 启动主应用
# ==============================
echo "[Kuma] 启动主应用..."
exec node server/server.js
