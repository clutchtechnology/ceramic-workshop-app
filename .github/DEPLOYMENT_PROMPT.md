# 工控机部署提示词文档

> **奥卡姆剃刀原则**: 只包含必要信息，避免冗余步骤
> **适用项目**: ceramic-workshop-app + ceramic-workshop-backend
> **目标**: 向 AI 描述部署需求时使用本提示词

---

## 📋 部署环境信息

### 工控机目录结构

```
D:\
├── moliaochejian\                      # Flutter 应用目录
│   └── Release\                        # 当前运行版本
│       ├── ceramic_workshop_app.exe
│       ├── flutter_windows.dll
│       ├── *.dll (其他插件)
│       └── data\                       # 应用资源文件
│
├── deploy\                             # Docker 后端版本库
│   ├── 1.0.0\
│   ├── 1.1.12\                         # 当前运行版本
│   │   ├── ceramic-backend-1.1.12.tar  # Docker 镜像
│   │   ├── docker-compose.yml          # 容器编排配置
│   │   └── README.md                   # 版本说明
│   └── 1.x.x\                          # 新版本放这里
│
└── data\                               # 数据持久化目录 (勿删)
    ├── influxdb\                       # 时序数据库数据
    └── logs\                           # 应用日志
```

### 当前运行服务

```powershell
# Docker 容器状态
CONTAINER ID   IMAGE                    PORTS                     NAMES
b5c0519e477f   ceramic-backend:1.1.12   0.0.0.0:8080->8080/tcp    ceramic-backend
24c25bb33f4f   influxdb:2.7             0.0.0.0:8086->8086/tcp    ceramic-influxdb

# 后端 API 地址
http://localhost:8080
```

---

## 🚀 部署提示词模板

### A. Flutter 应用更新

**提示词**:

```
我需要将 Flutter 应用部署到工控机:

1. 开发机路径: 
   ceramic-workshop-app\build\windows\x64\runner\Release\

2. 工控机目标路径: 
   D:\moliaochejian\Release\

3. 操作需求:
   - 停止正在运行的 ceramic_workshop_app.exe
   - 备份当前 Release 目录为 Release_backup_{日期}
   - 将新的 Release 目录完整复制到 D:\moliaochejian\
   - 验证必要文件是否存在 (exe, dll, data/)
   - 启动新版本应用
   - 测试连接后端: http://localhost:8080/api/health

4. 注意事项:
   - 保留 data\logs\ 目录 (如果有日志)
   - 检查看门狗程序是否需要重启
```

---

### B. Docker 后端更新

**提示词**:

```
我需要部署新版本 Docker 后端到工控机:

1. 新版本信息:
   - 版本号: {例如 1.1.13}
   - 开发机构建:
     cd ceramic-workshop-backend
     docker build -t ceramic-backend:{版本号} .
     docker save -o ceramic-backend-{版本号}.tar ceramic-backend:{版本号}

2. 工控机部署路径:
   D:\deploy\{版本号}\
   需要包含:
   - ceramic-backend-{版本号}.tar
   - docker-compose.yml (更新镜像版本号)
   - README.md (版本说明)

3. 操作流程:
   # 停止旧容器
   docker-compose -f D:\deploy\1.1.12\docker-compose.yml down

   # 加载新镜像
   docker load -i D:\deploy\{版本号}\ceramic-backend-{版本号}.tar

   # 启动新容器
   docker-compose -f D:\deploy\{版本号}\docker-compose.yml up -d

   # 验证服务
   docker ps
   curl http://localhost:8080/api/health

4. 注意事项:
   - InfluxDB 数据在 D:\data\influxdb\ (不会丢失)
   - 旧版本容器仅停止，不删除 (可回滚)
   - 检查端口 8080/8086 是否被占用
```

---

### C. 完整系统部署 (首次或重置)

**提示词**:

```
我需要在新工控机上完整部署系统:

1. 前置要求:
   - Windows 10/11 x64
   - Docker Desktop 已安装并启动
   - 磁盘 D:\ 至少 10GB 可用空间

2. 创建目录结构:
   New-Item -Path "D:\moliaochejian\Release", "D:\deploy", "D:\data" -ItemType Directory -Force

3. Flutter 应用:
   - 复制 ceramic-workshop-app\build\windows\x64\runner\Release\* 到 D:\moliaochejian\Release\

4. Docker 后端:
   a. 复制最新版本目录到 D:\deploy\{版本号}\
   b. 加载镜像: docker load -i D:\deploy\{版本号}\ceramic-backend-{版本号}.tar
   c. 拉取 InfluxDB: docker pull influxdb:2.7
   d. 启动服务: docker-compose up -d

5. 验证:
   - 后端健康: curl http://localhost:8080/api/health
   - 启动应用: D:\moliaochejian\Release\ceramic_workshop_app.exe
   - 检查应用是否能正常连接后端

6. 配置看门狗 (可选):
   - 使用 app_watchdog.ps1 设置自动重启
```

---

## 🔧 快捷命令参考

### Flutter 开发机构建

```powershell
# 进入项目目录
cd ceramic-workshop-app

# 构建 Release 版本
flutter build windows --release

# 构建产物位置
# build\windows\x64\runner\Release\
```

### Docker 开发机构建

```powershell
# 进入项目目录
cd ceramic-workshop-backend

# 方式 1: docker-compose 构建
docker-compose --profile mock build
docker save -o ceramic-backend-{版本号}.tar ceramic-backend:{版本号}

# 方式 2: Dockerfile 直接构建
docker build -t ceramic-backend:{版本号} .
docker save -o ceramic-backend-{版本号}.tar ceramic-backend:{版本号}

# 准备部署包
mkdir D:\deploy\{版本号}
copy ceramic-backend-{版本号}.tar D:\deploy\{版本号}\
copy docker-compose.yml D:\deploy\{版本号}\
```

### 工控机容器管理

```powershell
# 查看运行状态
docker ps

# 查看日志 (实时)
docker logs -f ceramic-backend

# 停止服务
docker-compose down

# 启动服务 (Mock 模式)
docker-compose --profile mock up -d

# 启动服务 (生产模式)
docker-compose --profile production up -d

# 重启容器
docker-compose restart

# 查看资源占用
docker stats
```

---

## ❗ 常见问题排查

### 问题 1: 应用无法连接后端

**检查步骤**:

```powershell
# 1. 检查后端是否运行
docker ps | Select-String "ceramic-backend"

# 2. 测试后端接口
curl http://localhost:8080/api/health

# 3. 查看后端日志
docker logs ceramic-backend --tail 50

# 4. 检查防火墙
Test-NetConnection -ComputerName localhost -Port 8080
```

### 问题 2: Docker 容器启动失败

**检查步骤**:

```powershell
# 1. 查看详细错误
docker-compose logs

# 2. 检查端口占用
netstat -ano | Select-String "8080|8086"

# 3. 验证镜像完整性
docker images | Select-String "ceramic-backend"

# 4. 重新加载镜像
docker load -i D:\deploy\{版本号}\ceramic-backend-{版本号}.tar
```

### 问题 3: InfluxDB 数据丢失

**检查步骤**:

```powershell
# 1. 确认数据卷映射
docker inspect ceramic-influxdb | Select-String "Mounts" -Context 5

# 2. 检查数据目录
Test-Path D:\data\influxdb

# 3. 查看 docker-compose.yml 卷配置
# 确保有: - D:/data/influxdb:/var/lib/influxdb2
```

---

## 📝 版本命名规范

### 语义化版本号

```
格式: MAJOR.MINOR.PATCH

MAJOR: 重大架构变更 (不兼容旧版本)
MINOR: 新功能添加 (向后兼容)
PATCH: Bug 修复 (向后兼容)

示例:
1.0.0  - 初始版本
1.1.0  - 新增料仓监控模块
1.1.12 - 修复温度显示 Bug
2.0.0  - 重构为微服务架构
```

### 部署目录命名

```
D:\deploy\
├── 1.0.0\     # 首个生产版本
├── 1.1.0\     # 新功能版本
├── 1.1.12\    # 当前稳定版本
└── 1.2.0\     # 待部署版本 (测试中)
```

---

## 🎯 AI 助手快速指令

### 指令 1: 构建新版本部署包

```
请帮我构建版本 {X.Y.Z} 的部署包:
1. Flutter 应用构建命令
2. Docker 镜像构建命令
3. 准备 deploy/{X.Y.Z}/ 目录的文件清单
4. 生成版本 README.md 说明文件
```

### 指令 2: 生成部署脚本

```
请生成 PowerShell 部署脚本 (deploy_v{X.Y.Z}.ps1):
- 自动停止旧版本
- 加载新 Docker 镜像
- 更新 Flutter 应用
- 验证服务启动
- 输出部署报告
```

### 指令 3: 回滚到旧版本

```
需要回滚到版本 {X.Y.Z}:
1. 停止当前容器命令
2. 启动旧版本容器命令
3. 恢复旧版本 Flutter 应用
4. 验证回滚成功
```

---

## 📌 关键路径速查

| 项目 | 路径 |
|------|------|
| **工控机应用** | `D:\moliaochejian\Release\` |
| **Docker 版本库** | `D:\deploy\{版本号}\` |
| **数据持久化** | `D:\data\` |
| **后端 API** | `http://localhost:8080` |
| **InfluxDB** | `http://localhost:8086` |
| **开发机 Flutter** | `ceramic-workshop-app\build\windows\x64\runner\Release\` |
| **开发机后端** | `ceramic-workshop-backend\` |

---

**最后更新**: 2026-01-10  
**维护者**: 工控系统开发团队  
**版本**: v1.0
