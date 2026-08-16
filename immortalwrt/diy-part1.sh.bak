#!/usr/bin/env bash
set -e

# ======================================
# 替换官方精简版 Argon 为 jerrykuku 原版（带原生拾色器）
# 适配 ImmortalWrt SNAPSHOT / LuCI 26 / 内核 6.x
# ======================================

# 1. 删除官方 feed 自带的精简版 Argon（避免同名冲突）
# 递归查找 package 目录下所有官方 argon 相关包，不存在也不报错
find ./package -type d -name "luci-theme-argon" -exec rm -rf {} + 2>/dev/null
find ./package -type d -name "luci-app-argon-config" -exec rm -rf {} + 2>/dev/null
# 若 feeds 已提前拉取，也一并删除（兼容部分编译流程）
find ./feeds -type d -name "luci-theme-argon" -exec rm -rf {} + 2>/dev/null
find ./feeds -type d -name "luci-app-argon-config" -exec rm -rf {} + 2>/dev/null

# 2. 克隆 jerrykuku 原版 Argon（带原生 HTML5 拾色器）
# 用 --depth 1 加速克隆，失败自动重试 3 次
echo "Cloning jerrykuku/luci-theme-argon..."
for i in {1..3}; do
  git clone --depth 1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon && break
  echo "Clone luci-theme-argon failed, retry $i..."
  sleep 2
done

# 3. 克隆 jerrykuku 原版 Argon 配置插件（完整设置页，含拾色器逻辑）
echo "Cloning jerrykuku/luci-app-argon-config..."
for i in {1..3}; do
  git clone --depth 1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config && break
  echo "Clone luci-app-argon-config failed, retry $i..."
  sleep 2
done

# 4. 设置默认主题为 Argon（刷机后无需手动切换）
# 修改 LuCI 集合默认配置，适配 ImmortalWrt 官方源码结构
sed -i 's/LUCI_DEFAULT_THEME:=bootstrap/LUCI_DEFAULT_THEME:=argon/' feeds/luci/collections/luci/Makefile 2>/dev/null || true
# 兜底适配其他可能的源码路径
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true

# 5. 自动处理 .config 配置（避免漏选包）
if [ -f .config ]; then
  # 移除默认的 bootstrap 主题
  sed -i 's/CONFIG_PACKAGE_luci-theme-bootstrap=y/# CONFIG_PACKAGE_luci-theme-bootstrap is not set/' .config
  # 强制勾选 Argon 主题和配置插件
  echo -e "\nCONFIG_PACKAGE_luci-theme-argon=y\nCONFIG_PACKAGE_luci-app-argon-config=y" >> .config
fi

echo "✅ Argon 原版替换完成，后续正常执行 feeds update/install 和编译即可"
