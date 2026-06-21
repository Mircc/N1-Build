#!/bin/bash
# OpenWrt N1 & X86 自动编译 - Git 初始化脚本
# 用法：./init-repo.sh <your-github-username> <repo-name>

USERNAME="${1:-Mircc}"
REPO_NAME="${2:-N1-Build}"

echo "========================================="
echo "  Git 初始化脚本"
echo "  GitHub 用户名: $USERNAME"
echo "  仓库名: $REPO_NAME"
echo "========================================="
echo ""

# 1. 初始化 Git
git init
git branch -M main

# 2. 设置文件权限
chmod +x immo_diy.sh

# 3. 添加所有文件
git add .

# 4. 首次提交
git commit -m "Initial commit: N1 & X86 ImmortalWrt auto build

- N1 (s905d) build workflow
- X86_64 build workflow  
- Default IP: 192.168.50.200
- Plugins from openwrt_immortalwrt_mini.yml"

echo ""
echo "========================================="
echo "  下一步操作："
echo "  1. 在 GitHub 上创建名为 $REPO_NAME 的空仓库"
echo "  2. 运行以下命令推送："
echo ""
echo "     git remote add origin https://github.com/$USERNAME/$REPO_NAME.git"
echo "     git push -u origin main"
echo ""
echo "  3. 进入仓库 → Settings → Actions → 启用 Actions"
echo "  4. 进入 Actions 页面 → 选择 workflow → Run workflow"
echo "========================================="
