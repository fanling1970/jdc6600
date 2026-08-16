#!/usr/bin/env bash
set -e

# ======================================
# 替换官方精简版 Argon 为 jerrykuku 原版（带原生拾色器）
# 适配 ImmortalWrt SNAPSHOT / LuCI 26 / 内核 6.x
# ======================================

# 1. 删除官方 feed 自带的精简版 Argon（避免同名冲突）
find ./package -type d -name "luci-theme-argon" -exec rm -rf {} + 2>/dev/null
find ./package -type d -name "luci-app-argon-config" -exec rm -rf {} + 2>/dev/null
find ./feeds -type d -name "luci-theme-argon" -exec rm -rf {} + 2>/dev/null
find ./feeds -type d -name "luci-app-argon-config" -exec rm -rf {} + 2>/dev/null

# 2. 克隆 jerrykuku 原版 Argon
echo "Cloning jerrykuku/luci-theme-argon..."
for i in {1..3}; do
  git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon && break
  echo "Clone luci-theme-argon failed, retry $i..."
  sleep 2
done

# 3. 克隆 jerrykuku/luci-app-argon-config
echo "Cloning jerrykuku/luci-app-argon-config..."
for i in {1..3}; do
  git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config && break
  echo "Clone luci-app-argon-config failed, retry $i..."
  sleep 2
done

# ==========重点修改============
# feeds还未update，此时不要尝试修改feeds下Makefile！！
# 设置默认主题不要在part1做，挪到 diy‑part2.sh（feeds install完成之后）

# 4. 仅处理 .config（存在才修改，不存在跳过）
if [ -f .config ]; then
  sed -i 's/CONFIG_PACKAGE_luci-theme-bootstrap=y/# CONFIG_PACKAGE_luci-theme-bootstrap is not set/' .config
  echo -e "\nCONFIG_PACKAGE_luci-theme-argon=y\nCONFIG_PACKAGE_luci-app-argon-config=y" >> .config
fi

echo "✅ Argon 源码拉取完成；默认主题设置移至 diy‑part2.sh"
