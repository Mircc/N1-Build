# 编译失败记录 — 2026-07-26 (N1 / build-n1.yml)

## 失败现象
GitHub Actions 运行 `build-n1.yml`，在生成 armsr/armv8 的 ext4 根文件系统镜像时失败，
`make: *** [world] Error 2`，整个编译中止（未产出任何固件）。

## 根因
根文件系统分区默认只有 **160 MB**（`make_ext4fs -l 167772160`），而固件中集成的
第三方插件（passwall / openclash / mosdns / adguardhome / filebrowser / qbittorrent-ee /
netdata / openlist2 / 主题 等）打包后体积超过 160 MB，镜像空间不足。

关键报错（build-n1.log 第 59363 行）：
```
error: ext4_allocate_best_fit_partial: failed to allocate 1287 blocks, out of space?
make[5]: *** [/workdir/openwrt/include/image.mk:434: .../root.ext4] Error 1
make[4]: *** [Makefile:22: install] Error 2
make[3]: *** [Makefile:12: install] Error 2
    ERROR: target/linux failed to build.
```

注意：X86 工作流（build-x86.yml）早已设置 `CONFIG_TARGET_ROOTFS_PARTSIZE=1024`，
因此只有 N1 的 armsr 段缺这个配置才触发本问题。Docker 本地编译脚本的 armsr 段也漏了。

## 修复
在以下两处「镜像设置」块补充分区大小配置：
- `.github/workflows/build-n1.yml` → 新增 `CONFIG_TARGET_ROOTFS_PARTSIZE=1024`
- `docker/scripts/entrypoint.sh` (armsr 段) → 新增 `CONFIG_TARGET_ROOTFS_PARTSIZE=1024`

（X86 工作流与 Docker 的 X86 段原本已正确设置，无需改动。）

## 文件清单
- `build-n1.log`：完整编译日志（59391 行）
- `system.txt`：Workflow 系统/调度信息
