# Docker 部署指南

## 概述

本项目提供了完整的 Docker 化解决方案，包括：
- 多阶段构建 Dockerfile
- GitHub Actions 自动化工作流
- 多平台支持（linux/amd64, linux/arm64）

## 文件说明

### 1. Dockerfile
- **多阶段构建**：前端构建 → Go 构建 → 运行时镜像
- **安全性**：使用非 root 用户运行
- **健康检查**：自动检测服务状态
- **优化**：静态编译，最小化镜像体积

### 2. .dockerignore
- 优化构建上下文，排除不必要的文件
- 减少镜像构建时间和大小

### 3. GitHub Actions 工作流 (.github/workflows/docker-build.yml)
- **触发条件**：
  - Push 到 main 分支
  - 手动触发 (workflow_dispatch)
- **多平台构建**：linux/amd64, linux/arm64
- **多标签推送**：latest, commit SHA, timestamp
- **安全扫描**：Trivy 漏洞扫描

## 环境变量配置

在 GitHub 仓库设置中，需要配置以下变量：

### Repository Variables
```
DOCKER_REPO=your-registry.com
DOCKER_USERNAME=your-username
```

### Repository Secrets
```
DOCKER_PASSWORD=your-password-or-token
```

## 本地构建

### 构建镜像
```bash
docker build -t file-transfer-go .
```

### 运行容器
```bash
docker run -p 8080:8080 file-transfer-go
```

### 多平台构建
```bash
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 -t file-transfer-go .
```

## 生产部署

### 使用 Docker Compose
```yaml
version: '3.8'
services:
  file-transfer:
    image: ${DOCKER_REPO}/nekogeek/file-transfer-go:latest
    ports:
      - "8080:8080"
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 5s
```

### 使用 Kubernetes
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: file-transfer-go
spec:
  replicas: 2
  selector:
    matchLabels:
      app: file-transfer-go
  template:
    metadata:
      labels:
        app: file-transfer-go
    spec:
      containers:
      - name: file-transfer-go
        image: ${DOCKER_REPO}/nekogeek/file-transfer-go:latest
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: file-transfer-go-service
spec:
  selector:
    app: file-transfer-go
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
  type: LoadBalancer
```

## CI/CD 工作流程

1. **代码推送到 main 分支**
2. **GitHub Actions 自动触发**
3. **多阶段构建**：
   - 构建前端 (Next.js SSG)
   - 构建 Go 后端并嵌入前端
   - 创建最终运行时镜像
4. **多平台构建**：同时构建 amd64 和 arm64 版本
5. **推送到镜像仓库**：使用多个标签
6. **安全扫描**：Trivy 漏洞扫描
7. **构建摘要**：生成详细的构建报告

## 镜像标签策略

- `latest`：最新的 main 分支构建
- `{commit-sha}`：特定提交的构建
- `{timestamp}`：带时间戳的构建版本

## 监控和日志

### 健康检查
容器内置健康检查，每30秒检查一次服务状态。

### 日志查看
```bash
# 查看容器日志
docker logs -f <container-id>

# 在 Kubernetes 中查看日志
kubectl logs -f deployment/file-transfer-go
```

## 故障排除

### 构建失败
1. 检查 GitHub Actions 日志
2. 验证环境变量配置
3. 确认 Docker 镜像仓库访问权限

### 运行时问题
1. 检查容器健康状态：`docker ps`
2. 查看容器日志：`docker logs <container-id>`
3. 进入容器调试：`docker exec -it <container-id> sh`

### 网络问题
1. 确认端口映射正确：`-p 8080:8080`
2. 检查防火墙设置
3. 验证服务是否在容器内正常启动

## 安全建议

1. **使用非 root 用户**：容器内使用 `appuser` 运行
2. **定期更新基础镜像**：及时应用安全补丁
3. **漏洞扫描**：集成 Trivy 安全扫描
4. **最小权限原则**：只暴露必要的端口和功能
5. **镜像签名**：考虑使用 Docker Content Trust

## 性能优化

1. **多阶段构建**：减少最终镜像大小
2. **构建缓存**：利用 GitHub Actions 缓存
3. **静态编译**：减少运行时依赖
4. **资源限制**：在生产环境中设置合适的资源限制

```yaml
resources:
  limits:
    memory: "512Mi"
    cpu: "500m"
  requests:
    memory: "256Mi"
    cpu: "250m"