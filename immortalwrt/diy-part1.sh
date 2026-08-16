#!/usr/bin/env bash
set -e

# 删除旧argon，||true防止目录不存在直接崩溃
find ./package -type d -name "luci-theme-argon" -exec rm -rf {} + 2>/dev/null || true
find ./package -type d -name "luci-app-argon-config" -exec rm -rf {} + 2>/dev/null || true
find ./feeds -type d -name "luci-theme-argon" -exec rm -rf {} + 2>/dev/null || true
find ./feeds -type d -name "luci-app-argon-config" -exec rm -rf {} + 2>/dev/null || true

# 拉取原版argon
echo "Cloning jerrykuku/luci-theme-argon..."
for i in {1..3}; do
  git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon && break
  sleep 2
done

echo "Cloning jerrykuku/luci-app-argon-config..."
for i in {1..3}; do
  git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config && break
  sleep 2
done

echo "✅ part1: Argon源码拉取完成"
