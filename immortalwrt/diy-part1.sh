#!/usr/bin/env bash
set -e

# 删除旧argon
find ./package -type d -name "luci-theme-argon" -exec rm -rf {} + 2>/dev/null || true
find ./package -type d -name "luci-app-argon-config" -exec rm -rf {} + 2>/dev/null || true
find ./feeds -type d -name "luci-theme-argon" -exec rm -rf {} + 2>/dev/null || true
find ./feeds -type d -name "luci-app-argon-config" -exec rm -rf {} + 2>/dev/null || true

# 拉取原版argon theme（明确指定master分支，适配新版LuCI）
echo "Cloning jerrykuku/luci-theme-argon..."
for i in {1..3}; do
  git clone --depth 1 --single-branch --branch master https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon && break
  sleep 2
done

# 拉取argon-config，完整克隆，并指定master分支
echo "Cloning jerrykuku/luci-app-argon-config..."
for i in {1..3}; do
  git clone --single-branch --branch master https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config && break
  sleep 2
done

# 回退到拾色器正常可用版本
cd package/luci-app-argon-config
git reset --hard 918e849040e04517425104306223710966229623
cd ../../

echo "✅ part1: Argon源码拉取完成"
