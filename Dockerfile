# 基于轻量化的 uptime-kuma:2-slim 镜像
FROM louislam/uptime-kuma:2-slim

# 切换回 root 以进行系统级配置
USER root

# 设置时区
ENV TZ=Asia/Shanghai
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 从其他镜像复制必要的二进制文件
COPY --from=ghcr.io/sagernet/sing-box:latest /usr/local/bin/sing-box /usr/local/bin/sing-box
COPY --from=ghcr.io/komari-monitor/komari-agent:latest /app/komari-agent /app/komari-agent

# 设置工作目录
WORKDIR /app

# 1. 删除有漏洞的 healthcheck 二进制文件
# 2. 预创建数据目录
# 3. 统一授权给 10014 和 root 组 (GID 0)
RUN rm -f /app/extra/healthcheck && \
    mkdir -p /app/data/upload /app/data/screenshots /app/data/db /app/data/docker-tls && \
    chown -R 10014:0 /app && \
    chmod -R 775 /app

# 复制脚本并修改所有权
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && chown 10014:0 /app/entrypoint.sh

# 环境变量：确保 Kuma 知道数据存哪
ENV DATA_DIR=/app/data/
ENV UPTIME_KUMA_DB_SSL=true

# 切换到特定的 UID
USER 10014

# 暴露端口
EXPOSE 3001

# 设置入口点脚本
CMD ["/app/entrypoint.sh"]
