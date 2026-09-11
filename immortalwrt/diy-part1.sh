#!/bin/bash
# ============================================================
# diy-part1.sh —— 在 feeds update 之前执行
# 用途：将第三方软件包源码克隆进源码 package/ 目录
# ============================================================

# ---- Aurora 主题：配置中心 + 主题本体（必须成对添加） ----
git clone --depth 1 https://github.com/eamonxg/luci-app-aurora-config.git package/luci-app-aurora-config
git clone --depth 1 https://github.com/eamonxg/luci-theme-aurora.git package/luci-theme-aurora

# 如需锁定到某个已验证的 Commit（推荐），把上面两行换成：
# git clone https://github.com/eamonxg/luci-app-aurora-config.git package/luci-app-aurora-config
# (cd package/luci-app-aurora-config && git checkout <COMMIT_HASH> && cd ../..)
# git clone https://github.com/eamonxg/luci-theme-aurora.git package/luci-theme-aurora
# (cd package/luci-theme-aurora && git checkout <COMMIT_HASH> && cd ../..)
