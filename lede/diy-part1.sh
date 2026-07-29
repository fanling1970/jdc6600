#!/bin/bash
# diy-part1.sh - 在 feeds update 之前执行
set -e

echo "=== [DIY-P1] 开始配置 feeds 源 ==="

# ======================================
# 1. 添加 feeds 源（必须在 feeds update 之前）
# ======================================
echo "--- 添加 feeds 源 ---"

# 添加 helloworld（SSR 插件）
echo 'src-git helloworld https://github.com/fw876/helloworld.git' >> feeds.conf.default

# ★ 添加 kenzok8 三方包源（含 dockerman）
# 注意：只加 kenzo 一个就够了，不要加 small，避免引入过多包产生冲突
# echo 'src-git kenzo https://github.com/kenzok8/openwrt-packages.git' >> feeds.conf.default

# 添加 iStore 软件中心
echo 'src-git istore https://github.com/linkease/istore;main' >> feeds.conf.default

# 添加 NAS 插件
echo 'src-git nas https://github.com/linkease/nas-packages.git;master' >> feeds.conf.default
echo 'src-git nas_luci https://github.com/linkease/nas-packages-luci.git;main' >> feeds.conf.default

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
# 2b. ★ 彻底清除 luci 自带的 dockerman（关键！让 kenzo 三方源接管）
# ======================================
echo "--- 清除 luci 自带 dockerman，改用 kenzo 三方源 ---"
# 删目录
rm -rf feeds/luci/applications/luci-app-dockerman 2>/dev/null || true
rm -rf feeds/luci/libs/luci-lib-docker 2>/dev/null || true
# 清索引（让 feeds install 不会再从 luci 装）
sed -i '/^Package: luci-app-dockerman$/,/^$/d' feeds/luci.index 2>/dev/null || true
sed -i '/^Package: luci-lib-docker$/,/^$/d' feeds/luci.index 2>/dev/null || true
echo "✅ luci 自带 dockerman 已清除，将由 kenzo 源提供"

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
rm -rf package/luci-theme-argon package/luci-app-argon-config package/luci-app-athena-led 2>/dev/null || true
rm -rf package/luci-app-dockerman package/luci-lib-docker 2>/dev/null || true
echo "✅ package/ 目录清理完成"

echo "✅ [DIY-P1] feeds 配置完成"
