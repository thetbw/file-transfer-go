FROM alpine:latest

RUN mkdir -p /opt/app

COPY dist/ /opt/app/

WORKDIR /opt/app
# 设置文件权限
RUN chmod +x /opt/app/file-transfer-server-linux-amd64

# 暴露端口
EXPOSE 8080

RUN apk add --no-cache ca-certificates curl

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# 启动应用
CMD ["./file-transfer-server-linux-amd64"]