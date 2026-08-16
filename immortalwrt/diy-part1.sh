#!/usr/bin/env bash
set -e

# 删除旧argon
find ./package -type d -name "luci-theme-argon" -exec rm -rf {} + 2>/dev/null || true
find ./package -type d -name "luci-app-argon-config" -exec rm -rf {} + 2>/dev/null || true
find ./feeds -type d -name "luci-theme-argon" -exec rm -rf {} + 2>/dev/null || true
find ./feeds -type d -name "luci-app-argon-config" -exec rm -rf {} + 2>/dev/null || true

# 拉取原版argon theme（master分支，适配新版LuCI）
echo "Cloning jerrykuku/luci-theme-argon..."
for i in {1..3}; do
  git clone --depth 1 --single-branch --branch master https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon && break
  sleep 2
done

# 拉取argon-config（master分支，适配ImmortalWrt）
echo "Cloning jerrykuku/luci-app-argon-config..."
for i in {1..3}; do
  git clone --depth 1 --single-branch --branch master https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config && break
  sleep 2
done

echo "✅ part1: Argon源码拉取完成"
