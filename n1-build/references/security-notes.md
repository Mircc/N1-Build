# 安全 CVE 信息注入方案

在 Release Notes 中自动加入当前编译版本修复的安全漏洞信息。

## 1. 数据源

### 1.1 OpenWrt 官方发布说明（推荐）

格式：`https://openwrt.org/releases/{major.minor}/notes-{major.minor.patch}`

示例（当前稳定版）：
- 列表页：`https://openwrt.org/releases/25.12/start`（含所有 25.12.x 版本链接）
- 说明页：`https://openwrt.org/releases/25.12/notes-25.12.5`

**Security fixes 章节结构**（DokuWiki 渲染的 HTML）：
- 按组件分组：odhcpd / uhttpd / cgi-io / LuCI / ead / Linux kernel / OpenSSL / musl / dropbear
- 每个漏洞：CVE 编号（如有）+ 严重等级（Critical/High/Moderate）+ 描述 + GHSA 链接
- 25.12.5 单版本含 24 个 CVE + 9 个未编号漏洞

> 抓取列表页可动态获取最新点版本号，避免硬编码 25.12.5 后页面 404。

### 1.2 内核 ChangeLog（补充）

格式：`https://cdn.kernel.org/pub/linux/kernel/v6.x/ChangeLog-{version}`

- 例：`https://cdn.kernel.org/pub/linux/kernel/v6.x/ChangeLog-6.12.94`
- 内容：原始 git commit 记录，**无 CVE 标注**
- 用途：交叉引用 + 提供链接，不作为主信息源

### 1.3 NVD CVE 数据库（可选，复杂度高）

- API：`https://services.nvd.nist.gov/rest/json/cves/2.0?cpeName=...`
- 适合按内核/CVE 编号精确查询，但需处理速率限制

## 2. 版本检测

| 目标 | 方法 | 注意点 |
|------|------|--------|
| OpenWrt 版本 | 固件产物 `/etc/openwrt_release` 的 `DISTRIB_RELEASE`，或 `.config` 的 `CONFIG_VERSION_NUMBER` | ImmortalWrt master 默认 `SNAPSHOT`，需映射到最近的 25.12.x |
| 内核版本 (N1) | `KernelVersion` 文件 `6.12.y` → 打包时解析为最新（如 6.12.94） | 实际版本在 `OldCoding/amlogic-s9xxx-openwrt` 打包后确定 |
| 内核版本 (X86) | 编译产物 `linux-*/` 目录名或 `vermagic` | 来自 OpenWrt 源码树 |

## 3. 实现步骤（workflow 新增 job/step）

```yaml
- name: Fetch security advisories
  if: steps.compile.outputs.status == 'success'
  run: |
    # 1. 获取最新 25.12.x 版本号
    LATEST=$(curl -s https://openwrt.org/releases/25.12/start \
      | grep -oE 'notes-25\.12\.[0-9]+' | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    echo "LATEST_OPENWRT=$LATEST" >> $GITHUB_ENV
    # 2. 抓取 Security fixes 段落（Python 解析 DokuWiki HTML）
    curl -s "https://openwrt.org/releases/25.12/notes-$LATEST" -o /tmp/notes.html
    python3 scripts/parse_security.py /tmp/notes.html > security.md
    echo "SECURITY_NOTES<<EOF" >> $GITHUB_ENV
    cat security.md >> $GITHUB_ENV
    echo "EOF" >> $GITHUB_ENV
```

`scripts/parse_security.py` 伪代码：
```python
# 提取 <h3>Security fixes</h3> 到下一个 <h2>/<h3> 之间的内容
# 解析 <li> 条目 → 表格: | CVE | 等级 | 组件 | 描述 |
import sys, re, html
from bs4 import BeautifulSoup  # 或用正则
doc = BeautifulSoup(open(sys.argv[1]).read(), 'html.parser')
# 找到 Security fixes 标题，遍历后续兄弟直到下一个标题
# 输出 Markdown 表格
```

## 4. Release Body 注入

在 `ncipollo/release-action` 的 `body:` 中「主源码最近提交」与「使用说明」之间插入：

```markdown
## 🔒 安全修复 (基于 OpenWrt ${{ env.LATEST_OPENWRT }})

${{ env.SECURITY_NOTES }}

> 内核 6.12.94：含上游 6.12.88→6.12.94 安全修复
> 详细 ChangeLog: https://cdn.kernel.org/pub/linux/kernel/v6.x/ChangeLog-6.12.94
```

## 5. 注意事项

1. **ImmortalWrt master ≠ OpenWrt 稳定版**：建议固定引用最新 25.12.x notes 并标注「参考」，因 ImmortalWrt master 通常已含这些修复。
2. **404 容错**：若版本页不存在，跳过安全段落，不阻断发布。
3. **内核 CVE 不直接可得**：优先复用 OpenWrt notes 的内核段落（已引用 CVE-2026-43500 等），附 kernel.org 链接。
4. **DokuWiki HTML 解析脆弱**：OpenWrt 改版可能破坏选择器，需定期验证。

## 6. 体积/性能权衡

- 抓取 + 解析增加约 10–30 秒编译时间，可接受。
- 不下载固件源码，仅 HTTP GET 文本页面。
