# 多阶段构建 Dockerfile for file-transfer-go

# 阶段1: 构建前端 (Node.js)
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend

# 复制前端项目文件
COPY chuan-next/package.json chuan-next/yarn.lock ./
COPY chuan-next/ ./

# 安装依赖并构建前端
RUN yarn install --frozen-lockfile
RUN NEXT_EXPORT=true NODE_ENV=production NEXT_PUBLIC_BACKEND_URL= NEXT_PUBLIC_WS_URL= NEXT_PUBLIC_API_BASE_URL= yarn build

# 阶段2: 构建Go应用
FROM golang:1.21-alpine AS go-builder

# 安装构建依赖
RUN apk add --no-cache git ca-certificates

WORKDIR /app

# 复制Go模块文件
COPY go.mod go.sum ./
RUN go mod download

# 复制Go源代码
COPY cmd/ ./cmd/
COPY internal/ ./internal/

# 创建前端嵌入目录并复制前端构建文件
RUN mkdir -p internal/web/frontend
COPY --from=frontend-builder /app/frontend/out/ ./internal/web/frontend/

# 构建Go应用
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-s -w -extldflags '-static'" \
    -o file-transfer-go \
    ./cmd

# 阶段3: 运行时镜像
FROM alpine:latest

# 安装运行时依赖
RUN apk --no-cache add ca-certificates tzdata curl

# 创建非root用户
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

WORKDIR /app

# 复制二进制文件
COPY --from=go-builder /app/file-transfer-go .

# 设置文件权限
RUN chown appuser:appgroup /app/file-transfer-go && \
    chmod +x /app/file-transfer-go

# 切换到非root用户
USER appuser

# 暴露端口
EXPOSE 8080

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/ || exit 1

# 启动应用
CMD ["./file-transfer-go"]