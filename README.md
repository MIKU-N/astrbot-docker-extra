# AstrBot Extended Image

基于官方 [AstrBot](https://github.com/AstrBotDevs/AstrBot) 镜像构建的**扩展版镜像**：在官方镜像之上，额外预装三个常用插件所依赖的 Python 库，让你拉下镜像就能直接装插件用，**不需要在容器里现装编译型依赖**（faiss、scikit-learn 这类装起来很慢，还经常因为缺编译器或 numpy 版本冲突而失败）。

镜像会自动跟踪上游 AstrBot 的 `latest` / `nightly-latest`，并按 digest 锁定，保证可复现。

---

## 镜像地址

| 仓库 | 地址 |
| --- | --- |
| GitHub Container Registry | `ghcr.io/miku-n/astrbot-docker-extra` |
| Docker Hub | `docker.io/miku114514/astrbot-docker-extra` |

> Docker Hub 的仓库名可通过仓库变量 `DOCKERHUB_REPO` 覆盖；未配置时默认使用仓库名 `astrbot-docker-extra`。

### 标签约定

| 标签 | 含义 |
| --- | --- |
| `latest` | 稳定通道，跟随上游 `soulter/astrbot:latest` |
| `nightly-latest` | 预发布通道，跟随上游 `soulter/astrbot:nightly-latest` |
| `main` / `nightly-main` | 对应分支的构建产物 |
| `v1.0.0` / `1.0` | 语义化版本号 |
| `<commit-sha>` | 每次提交的构建产物 |

---

## 预装依赖 ↔ 目标插件

本镜像的额外依赖是为下面三个插件准备的：

| 插件 | 说明 | 插件自身声明的依赖 |
| --- | --- | --- |
| [astrbot_plugin_group_chat_plus](https://github.com/Him666233/astrbot_plugin_group_chat_plus) | 群聊聊天效果增强插件（读空气、主动对话、Web 管理面板） | `argon2-cffi>=23.1.0`、`aiohttp>=3.8.0` |
| [astrbot_plugin_livingmemory](https://github.com/lxfight-s-Astrbot-Plugins/astrbot_plugin_livingmemory) | 拥有完整记忆生命周期的智能长期记忆插件 | `networkx>=3.0`、`jieba>=0.42.1`、`pytz>=2021.3`、`aiofiles>=23.0.0`、`aiosqlite>=0.20.0` |
| [astrbot_plugin_self_learning](https://github.com/NickCharlie/astrbot_plugin_self_learning) | 自主学习插件（对话风格学习、社交关系与好感度、人格演化） | `fastapi>=0.124.0`、`uvicorn>=0.30.0`、`itsdangerous>=2.2.0`、`jinja2>=3.1.0` |

三个插件声明的依赖**均已包含在本镜像中**（`itsdangerous` / `jinja2` 由基础镜像自带的 `quart` 传递带入）。

### 依赖明细（按插件源码中的实际引用点）

**astrbot_plugin_self_learning** —— 依赖最重的一个：

- `sqlalchemy` + `asyncpg` + `aiomysql` —— 全部模型层与仓储层；`sqlalchemy_database_manager.py` 会按方言加载 PostgreSQL / MySQL 异步驱动
- `scikit-learn` —— `ml_analyzer.py`：KMeans、TF-IDF、逻辑回归、决策树、余弦相似度
- `networkx` —— `intelligence_enhancement.py`、`social_graph_analyzer.py`、`enhanced_memory_graph_manager.py`：社交关系与记忆图谱
- `lightrag-hku` —— `lightrag_knowledge_manager.py`：LightRAG 知识图谱
- `mem0ai` —— `mem0_memory_manager.py`：mem0 记忆后端
- `numpy` —— 向量运算
- `jieba` —— `jargon_statistical_filter.py`：黑话分词统计
- `emoji` —— `multidimensional_analyzer.py`：情绪维度分析
- `psutil` —— `collector.py`、`health_checker.py`：运行状态与健康检查
- `prometheus-client` / `prometheus-async` —— `metrics.py`、`instrumentation.py`：指标暴露
- `cachetools` —— `cache_manager.py`：TTL / LRU 缓存
- `apscheduler` —— `task_scheduler.py`：定时学习任务

**astrbot_plugin_livingmemory**：

- `faiss-cpu` —— `faiss_async_persist.py`、`plugin_initializer_faiss.py`、`faiss_path_bridge.py`：向量索引与持久化
- `numpy` —— 向量检索与重排
- `aiosqlite` —— 记忆、图谱、会话的存储与迁移
- `jieba` —— `text_processor.py`：中文分词
- `aiofiles` —— 停用词表、衰减调度等异步文件读写
- `quart` + `quart-cors` —— Pages 管理面板路由
- `sqlalchemy` —— `vector_retriever.py` 等向量检索模块
- `networkx` —— 图谱召回
- `pytz` —— 时区处理

**astrbot_plugin_group_chat_plus**：

- `argon2-cffi` —— `auth.py`：Web 面板口令的 Argon2id 内存硬化哈希
- `aiohttp` —— `server.py`：Web 管理面板的 HTTP 服务

完整清单见 [`astrbot-extra-requirements.txt`](astrbot-extra-requirements.txt)。

---

## 使用

```bash
docker run -d \
  --name astrbot \
  --restart always \
  -p 6185:6185 \
  -v ./data:/AstrBot/data \
  -e TZ=Asia/Shanghai \
  ghcr.io/miku-n/astrbot-docker-extra:latest
```

或使用 compose：

```yaml
services:
  astrbot:
    image: ghcr.io/miku-n/astrbot-docker-extra:latest
    container_name: astrbot
    restart: always
    ports:
      - "6185:6185" # AstrBot WebUI
    environment:
      - TZ=Asia/Shanghai
    volumes:
      - ./data:/AstrBot/data
      - /etc/localtime:/etc/localtime:ro
```

安装插件时，把插件目录放进 `./data/plugins/` 后在 WebUI 里重载即可。

---

## CI/CD 架构

工作流按**架构**与**版本**两个维度拆分，避免单文件塞满所有逻辑：

```
.github/workflows/
├── docker-build.yml          # 入口：push / PR / 手动触发
├── sync-upstream.yml         # 入口：定时检测上游镜像更新
├── channel-stable.yml        # 稳定通道：标签策略 + 锁文件 + 提升目标
├── channel-nightly.yml       # nightly 通道：nightly- 前缀 + 锁文件 + 提升目标
├── reusable-build-arch.yml   # 单架构构建 + 该架构的冒烟测试
├── reusable-publish.yml      # 合并双架构清单 + Docker Hub 同步 + 校验
└── reusable-promote.yml      # 候选标签 → latest / nightly-latest
.github/actions/              # 四个复合 Action：基础镜像解析 / 标签集计算 / 冒烟测试 / 上游检测
```

几个设计要点：

- **架构分离**：`amd64` 与 `arm64` 是两个独立 job、两个独立 runner、两个独立缓存作用域（`stable-amd64` / `stable-arm64` / `nightly-amd64` / `nightly-arm64`），各自构建、各自冒烟、各自失败互不阻塞。
- **先验证后打标签**：每个架构先按 digest 推送并完成冒烟测试，全部通过后才由合并步骤生成多架构清单。因此任何一个架构出问题，都不会产生可见的坏标签。
- **版本分离**：stable 与 nightly 是两个独立文件，标签前缀、锁文件、提升目标都是写死的字面量，而不是靠一个开关字符串区分。
- **上游自动跟随**：每 6 小时检查一次上游 `latest` 与 `nightly-latest`，有更新时按通道构建，并把新的 digest 写回 [`.upstream/`](.upstream) 下的锁文件。
- **重建门禁**：push 到 main 时先比对构建输入（`Dockerfile`、依赖清单、上游锁文件、`.github/`），**没有变化就跳过镜像构建**，避免每次提交都重复发布一个内容相同的新版本。手动触发（workflow_dispatch）始终构建。上游镜像更新由 `sync-upstream.yml` 负责：它用新 digest 构建并提升 `latest`，随后提交的锁文件带 `[skip ci]` 标记，不再重复构建同一个镜像。

### 所需密钥与变量

| 名称 | 类型 | 用途 |
| --- | --- | --- |
| `DOCKER_USERNAME` | Secret | Docker Hub 用户名；未配置时跳过 Docker Hub 同步（GHCR 不受影响） |
| `DOCKER_PASSWORD` | Secret | Docker Hub Access Token，不是账户密码 |
| `DOCKERHUB_REPO` | Variable（可选） | Docker Hub 仓库名，默认取仓库名 `astrbot-docker-extra` |

> Secret 名称必须与上表完全一致。工作流读取的是 `secrets.DOCKER_USERNAME` / `secrets.DOCKER_PASSWORD`，名字对不上时 Docker Hub 的登录与同步步骤会被**静默跳过**，只有 GHCR 推送照常进行。

---

## 目录结构

```
.
├── Dockerfile                          # 基于 soulter/astrbot 安装额外依赖
├── astrbot-extra-requirements.txt      # 额外依赖清单
├── .upstream/                          # 上游基础镜像的 digest 锁文件（自动维护）
└── .github/
    ├── workflows/                      # CI/CD 工作流
    └── actions/                        # 复合 Action
```

---

## 维护

**新增依赖**：改 `astrbot-extra-requirements.txt`，CI 会自动重新构建镜像。

**更新上游版本**：无需手动操作，`sync-upstream.yml` 会自动检测并锁定。但如果你想立刻跟进，直接改 `.upstream/latest.lock` 里的 digest 并推送即可触发重建。

> `.upstream/*.lock` 由 CI 自动维护，请勿手工编辑其中的 digest 行（注释可以加）。

**镜像继承上游的 AGPL-3.0 协议**，三个插件同样遵循各自仓库中的许可证。
