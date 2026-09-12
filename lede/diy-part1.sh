#!/bin/bash
# diy-part1.sh - 在 feeds update 之前执行
set -e

echo "=== [DIY-P1] 开始配置 feeds 源 ==="

# ======================================
# 1. 添加 feeds 源（必须在 feeds update 之前）
# ======================================
echo "--- 添加 feeds 源 ---"

# 在 diy-part1.sh 的 feeds 源部分添加
# echo 'src-git openclash https://github.com/vernesong/OpenClash.git' >> feeds.conf.default

# 添加 helloworld（SSR 插件）
echo 'src-git helloworld https://github.com/fw876/helloworld.git' >> feeds.conf.default

# 添加 iStore 软件中心
echo 'src-git istore https://github.com/linkease/istore;main' >> feeds.conf.default

# 添加 NAS 插件
echo 'src-git nas https://github.com/linkease/nas-packages.git;master' >> feeds.conf.default
echo 'src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main' >> feeds.conf.default

echo "✅ feeds 源添加完成"

git clone --depth 1 https://github.com/eamonxg/luci-app-aurora-config.git package/luci-app-aurora-config
git clone --depth 1 https://github.com/eamonxg/luci-theme-aurora.git package/luci-theme-aurora

echo "✅ [DIY-P1] feeds 配置完成"
