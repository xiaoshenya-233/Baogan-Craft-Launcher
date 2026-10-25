# Baogan Craft Launcher

基于 Flutter 的 Minecraft 风格启动器界面原型，适配桌面与窄屏布局。包含主页、导航、游戏版本选择、启动状态演示和冒险灵感卡片。界面默认使用思源黑体（Source Han Sans SC），字体文件内置于 `assets/fonts/SourceHanSansSC-Regular.otf`。

当前版本：**26.1Alpha2.1**（Hotfix）。Flutter 包版本为 `26.1.2+2`，Windows 资源版本为 `26.1.2.1`。

## 对于中国大陆地区暂停客户端下载功能通告
为响应相关法律法规，暂时不提供客户端下载服务，如果想使用此功能，请确保你在国外网络环境下运行。

## 插件系统Github仓库
我们在26.1Alpha2.1中新增插件功能，插件将由https://github.com/xiaoshenya-233/Baogan-Craft-Launcher-Plugin-Center 提供

## 运行

```sh
flutter pub get
flutter run -d windows
```

## 目录结构

首次启动必须选择启动器根目录，不能跳过；取消系统文件夹选择后会停留在引导页。之后所有启动器数据都集中在该目录下：

```text
<选择的根目录>/
└─ Baogan Craft Launcher/
   ├─ BGCL/
   │  ├─ config/           # launcher.json（主题、壁纸、启动器设置）
   │  ├─ data/             # 数据库
   │  ├─ runtime/          # Java 运行时及 java_runtimes.json
   │  ├─ cache/
   │  │  ├─ icons/         # 图标缓存
   │  │  └─ temp/          # 临时文件（可安全清理）
   │  ├─ logs/
   │  └─ user_data/
   │     └─ wallpapers/    # 玩家自定义壁纸
   └─ .minecraft/          # Minecraft 游戏根目录（gameDir）
```

根目录指针 `launcher_config.json` 与启动器可执行文件同级，不写入 AppData 或 Temp。只有完成目录选择后，才会创建上述目录。清理 `cache/temp` 时不会触碰 `user_data`。

## 当前范围

支持扫描本地 Minecraft 客户端、启动选中版本、下载原版游戏文件，以及通过 BMCLAPI 或官方源安装 Fabric、Forge 和 NeoForge。Windows 使用 `window_manager` 隐藏系统标题栏并提供自定义窗口控制。客户端详情中的 Java 支持手动选择；自动搜索会从环境变量、PATH、注册表、常见安装目录和启动器运行时目录多源收集候选，优先解析 JDK `release` 文件，失败后回退到 `java -version`（兼容 GBK 输出），并把验证结果缓存到 `BGCL/runtime/java_runtimes.json`。启动时优先选择匹配版本，若没有匹配项也会尝试其他可用 Java，不再在启动前强制阻止；如果启动失败且输出显示 Java 版本问题，会提示前往 Java 管理更换 Java。启动或切换客户端不会重复扫描 Java。

本地客户端版本识别采用 PCL2 的多源策略，即使客户端目录或 `id` 被改成任意名称也能还原信息：先递归读取 `inheritsFrom` 继承链，再从合并后的 `libraries` 中识别 `net.neoforged:neoforge`、`net.minecraftforge:forge`、`net.fabricmc:fabric-loader` 等坐标，最后从启动参数中的 `--fml.neoForgeVersion`、`--fml.forgeVersion`、`--fml.mcVersion` 反推加载器和 Minecraft 版本；无法确认时不会把自定义目录名误报为 Minecraft 版本。

每个客户端直接使用 `.minecraft/versions/<客户端>` 作为独立游戏目录，隔离存档、配置、模组、光影和材质包；游戏版本文件、库和资源仍共享。因此 `--gameDir` 指向客户端的版本目录，游戏实际读取的是 `.minecraft/versions/<客户端>/mods`，根目录 `.minecraft/mods` 不参与该客户端的加载；如需使用根目录模组，应把 JAR 放入当前客户端的 `mods` 文件夹。客户端详情的管理卡片可查看该客户端 `logs/latest.log`，支持刷新和直接打开日志文件夹；删除客户端会先确认，再只递归删除当前来源 `versions` 内的客户端目录，不会删除共享的 `libraries`、`assets` 或其他客户端。版本管理支持添加多个 `.minecraft` 文件夹来源；启动器始终只显示当前来源中的客户端，切换来源后会重新扫描该文件夹，也可在来源列表中切换、添加、更换或移除来源。下载客户端会直接安装到当前选择的 `.minecraft` 路径，并为每个版本创建独立的 `versions/<版本>` 目录；下载时可自定义客户端名称，名称会作为独立的版本文件夹，避免不同客户端共享游戏数据。Fabric 客户端安装完成后会自动将兼容的 Fabric API 下载到该客户端的 `mods` 文件夹。启动时按客户端所属来源读取对应的 `libraries`、`assets` 和客户端 JAR。模组、光影、材质包等资源直接下载到对应客户端的版本目录下。

主页只显示当前客户端名称、登录方式和底部切换卡片，启动配置已从设置页移除；点击登录方式卡片可切换本地档案、Microsoft 或第三方验证，点击切换卡片右侧的方形按钮即可查看当前客户端配置。

调试模式默认开启，可在“设置 → 调试与日志”关闭。日志写入 `BGCL/logs/launcher.log`，记录版本扫描、设置修改、下载任务、Java 选择、认证模式、完整启动参数（自动隐藏访问令牌）以及游戏进程的标准输出和错误输出。游戏输出按 UTF-8 解码；NeoForge 的 `LaunchServiceHandler.hideAccessToken` 会把 `--accessToken` 替换成八个雪花 `❄❄❄❄❄❄❄❄` 后再写入日志，这是加载器的脱敏行为，不是令牌损坏。调试模式开启时，启动器会用同一程序以独立进程打开“调试日志”窗口，实时跟随日志末尾，支持暂停、刷新、复制和打开日志文件夹；该窗口不会被启动器主窗口遮挡。启动失败时会显示退出代码、输出片段，并提供“打开调试日志”按钮。启动器还会对启动 classpath 去重，避免 NeoForge 的 `BootstrapLauncher` 因重复依赖抛出 `Duplicate key` 并以退出代码 1 结束；若日志显示 Iris 1.8.x 与 Sodium 0.8.x 的 `SodiumGameOptions$PerformanceSettings` 类不兼容，会提示将 Sodium 换成 0.6.13 或升级 Iris 到 1.8.14 以上。

OptiFine 使用独立安装器；Fabric API 和 Modrinth / CurseForge 资源可下载到所选客户端的独立目录。NeoForge 安装器下载完成后会在启动器内自动解包，修改其中的 `version.json` / `install_profile.json` 等元数据，把 `maven.neoforged.net` 替换为 `neoforged.forgecdn.net` 后重新打包并静默安装，不依赖用户配置系统代理。下载任务页按客户端或资源任务分组，客户端所需文件集中在同一大纲卡片内，组内显示单文件进度，组头显示总任务进度、已完成文件数和总下载速度；顶部实时预览使用胶囊样式。资源页默认使用聚合搜索，同时请求 Modrinth 与 CurseForge 并合并结果，也可单独切换来源；设置中可选择聚合搜索偏向某一平台，偏向时自动去除两平台重复出现的项目，仅单平台存在或没有重叠的结果始终保留。CurseForge 请求通过自建代理节点 `cf-api-proxy.xiaoshenya233.workers.dev` 完成（API Key 由云端注入），无需在客户端配置。资源页支持候选批量下载、分页和中文模组搜索：中文关键词直接查询本地中英文映射库，再分别以 Modrinth 标识符或 CurseForge 模组 ID 拉取项目；下载任务可以在资源下载页或新的“下载任务”页中查看和取消；侧边栏“下载任务”按钮和顶部实时下载提示都可进入该页面。每个客户端、模组或加载器下载会显示正在下载的文件，文件级队列最多同时执行 8 个任务，完成的文件会立即从列表移除。英文关键词搜索按标题与描述的词条契合度过滤，达到 50% 才显示。取消后会清理临时文件和未完成的客户端版本目录。模组详情按 Fabric、Forge、NeoForge 等加载器以及 Minecraft 版本筛选。首次下载资源时选择目标客户端，选择会保存在启动器设置中。

资源下载采用两级页面加详情页内版本区：资源列表 → 模组详情，详情页内直接显示版本筛选和小版本大纲卡片，不再需要额外的“选择下载版本”步骤。打开详情时会按分页拉取 Modrinth / CurseForge 的完整版本历史，而不是只显示第一页的热门文件；搜索结果页仍只加载当前页项目以保持响应速度。筛选顺序为先选 Minecraft 大版本，再显示该大版本实际适用的加载器类型；没有适用版本的加载器不会显示。缺少加载器元数据的旧文件会结合文件名、项目已知加载器或 Minecraft 世代推断，不会再把 1.12.2 的 Forge 文件误归到 Fabric。标签在显示前会经过本地 SQLite 标签翻译库：先用归一化规则统一 CurseForge 与 Modrinth 的不同写法（如 `Adventure and RPG` 与 `adventure`），再查询中英文缓存，数据库位于 `BGCL/data/tag_translations.sqlite`。RC/预发布版本归入所属数字主版本（例如 26.3、26.3-rc1、26.3-rc-2 同属 26.3，1.21.1-pre2 归入 1.21.1），纯周快照（如 24w14a）从版本筛选中过滤；小版本以大纲卡片展示，点击后在卡片内部展开可下载文件，每个文件同时提供“下载”和“候选”按钮，候选文件会记录具体版本。

OptiFine 安装仍需在其独立安装窗口中确认，并在安装后重新扫描版本。资源兼容性取决于上游服务返回的游戏版本和加载器元数据。

运行测试：`flutter test`

资源搜索标题会立即显示英文，并在后台通过 `mcmod-api.zkitefly.eu.org` 搜索中文名；中文名缓存到 `BGCL/data/mcmod_titles.sqlite` 的 `mods` 表，请求最大并发为 2，翻译失败时继续显示英文。版本详情默认显示“全部”加载器；无法从 API 判断加载器的旧文件会归入“未标注”筛选而不是被隐藏。`26.3-snapshot` 等命名快照归入所属 26.3 主版本，`24w14a` 这类纯周快照不进入版本筛选。缺少游戏版本字段的文件会尝试从文件名或 CurseForge `sortableGameVersions` 推断版本。
整合包导入支持 Modrinth `.mrpack` 和包含 `modrinth.index.json` 的 ZIP：读取 Minecraft/加载器依赖，补装原版与 Forge/Fabric/NeoForge，使用下载任务队列（最多 8 个文件并发）下载全部客户端文件并校验 SHA-1，最后解压 `overrides/` / `client-overrides/` 到独立的 `versions/<整合包名>` 客户端目录，生成可直接启动的版本配置。


