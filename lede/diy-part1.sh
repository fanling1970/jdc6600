#!/bin/bash
# diy-part1.sh - 在 feeds update 之前执行
set -e

echo "=== [DIY-P1] 开始配置 feeds 源 ==="

# ======================================
# 1. 添加 feeds 源（必须在 feeds update 之前）
# ======================================
echo "--- 添加 feeds 源 ---"

# 注意：kenzo 和 small 源已在 feeds.conf.default 中定义
# 此处仅做检查或补充，避免重复添加
if ! grep -q "src-git kenzo" feeds.conf.default; then
    echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages.git' >> feeds.conf.default
fi

if ! grep -q "src-git small" feeds.conf.default; then
    echo 'src-git small https://github.com/kenzok8/small.git' >> feeds.conf.default
fi

echo "✅ feeds 源添加完成"

# ======================================
# 2. 清理 Lean 自带旧版 argon（避免冲突）
# ======================================
echo "--- 清理 Lean 自带旧版 argon ---"
rm -rf feeds/luci/themes/luci-theme-argon 2>/dev/null || true
# 清理 feeds 索引中的引用
sed -i '/^Package: luci-theme-argon$/,$ {/^$/d; /^Package:/a auto-selected 0' feeds/luci.index 2>/dev/null || true
echo "✅ Lean 旧版 argon 已清除"

# ======================================
# 3. 升级 Golang 到 1.26（适配新协议）
# ======================================
echo "--- 升级 Golang 到 1.26 ---"
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang
echo "✅ Golang 升级完成"

# ======================================
# 4. 清理 package/ 目录残留（可选）
# ======================================
echo "--- 清理 package/ 目录残留 ---"
# 这些包现在从 kenzo feeds 安装，需确保 package/ 下无同名手动克隆残留
rm -rf package/luci-theme-argon package/luci-app-argon-config package/luci-app-athena-led 2>/dev/null || true
rm -rf package/luci-app-dockerman package/luci-lib-docker 2>/dev/null || true
# 清理可能存在的旧版 SSR+/OpenClash 手动包
rm -rf package/luci-app-ssr-plus package/luci-app-openclash 2>/dev/null || true
echo "✅ package/ 目录清理完成"

echo "✅ [DIY-P1] feeds 配置完成"
