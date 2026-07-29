#!/bin/bash
# diy-part2.sh - 在 feeds install 之后执行
echo "=== [DIY-P2] 开始配置第三方包和系统设置 ==="

# ======================================
# 0. 清理所有来源的旧 dockerman（确保不被干扰）
# ======================================
echo "--- 清理旧 dockerman ---"
rm -rf package/luci-app-dockerman package/luci-lib-docker 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-dockerman 2>/dev/null || true
rm -rf feeds/luci/libs/luci-lib-docker 2>/dev/null || true
# 禁用 luci-app-docker（互斥）
if [ -f .config ]; then
    sed -i '/CONFIG_PACKAGE_luci-app-docker=/d' .config
fi
echo "✅ 旧 dockerman 清理完成"

# ======================================
# 1. 克隆第三方包（全部走 git clone 到 package/，统一方式）
# ======================================
echo "--- 克隆 Argon 主题 ---"
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon || { echo "❌ Argon 失败"; exit 1; }

echo "--- 克隆 Argon 配置插件 ---"
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config || { echo "❌ Argon-config 失败"; exit 1; }
echo "✅ Argon 主题完成"

echo "--- 克隆 Athena LED ---"
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led || { echo "❌ Athena 失败"; exit 1; }
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led
chmod +x package/luci-app-athena-led/root/usr/sbin/athena-led
echo "✅ Athena LED 完成"

# ★★★ 核心：直接从 kenzok8 仓库提取 dockerman（绕过 feeds）★★★
echo "--- 克隆 kenzok8 dockerman（三方源）---"
# 浅克隆 kenzok8 仓库到临时目录
git clone --depth=1 https://github.com/kenzok8/openwrt-packages.git /tmp/kenzok8
# 只拷贝 dockerman 相关目录到 package/
cp -r /tmp/kenzok8/luci-app-dockerman package/luci-app-dockerman
cp -r /tmp/kenzok8/luci-lib-docker package/luci-lib-docker
# 清理临时目录
rm -rf /tmp/kenzok8
echo "✅ 三方 dockerman 克隆完成（来自 kenzok8/openwrt-packages）"

# ======================================
# 2. 基础系统设置（和你原来的一样，不动）
# ======================================
echo "--- 修改基础系统设置 ---"
sed -i "s/hostname='.*'/hostname='LEDE'/g" package/base-files/files/bin/config_generate
sed -i "s/DISTRIB_DESCRIPTION='*.*'/DISTRIB_DESCRIPTION='OpenWrt-$(date +%Y%m%d)'/g" package/lean/default-settings/files/zzz-default-settings
sed -i "s/DISTRIB_REVISION='*.*'/DISTRIB_REVISION=' By J.Y'/g" package/lean/default-settings/files/zzz-default-settings
sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate
sed -i '/V4UetPzk$CYXluq4wUazHjmCDBCqXF/d' package/lean/default-settings/files/zzz-default-settings
if ! grep -q "istore.channel" package/lean/default-settings/files/zzz-default-settings; then
    sed -i "/^uci commit istore/i uci set istore.istore.channel='OpenWrt'" package/lean/default-settings/files/zzz-default-settings
fi
echo "✅ 基础系统设置完成"

# ======================================
# 3. 清理冲突包
# ======================================
echo "--- 清理冲突包 ---"
rm -rf feeds/luci/applications/luci-app-istorex 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-quickstart 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-store 2>/dev/null || true
rm -rf feeds/luci/libraries/luci-lib-taskd 2>/dev/null || true
rm -rf feeds/luci/applications/quickstart 2>/dev/null || true
echo "✅ 冲突包清理完成"

# ======================================
# 4. 安装 feeds（不再尝试从 kenzo 装 dockerman）
# ======================================
echo "--- 更新并安装 feeds ---"
./scripts/feeds update helloworld istore nas nas_luci
./scripts/feeds install -a -p helloworld
./scripts/feeds install -d y -p istore luci-app-store
./scripts/feeds install -a -p nas
./scripts/feeds install -a -p nas_luci
echo "✅ feeds 安装完成"

# ======================================
# 5. 无线配置（不变）
# ======================================
echo "--- 配置无线网络 ---"
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-wireless << 'WIFIEOF'
#!/bin/sh
uci set wireless.radio0.channel='149'
uci set wireless.radio0.band='5g'
uci set wireless.radio0.htmode='HE80'
uci set wireless.default_radio0.ssid='JDC_AX6600_5G'
uci set wireless.default_radio0.key='BUZHIDAOWA'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.radio1.channel='6'
uci set wireless.radio1.band='2g'
uci set wireless.radio1.htmode='HT40'
uci set wireless.default_radio1.ssid='JDC_AX6600_2.4G'
uci set wireless.default_radio1.key='BUZHIDAOWA'
uci set wireless.default_radio1.encryption='psk2'
uci set wireless.radio2.channel='44'
uci set wireless.radio2.band='5g'
uci set wireless.radio2.htmode='HE160'
uci set wireless.default_radio2.ssid='JDC_AX6600_5G2'
uci set wireless.default_radio2.key='BUZHIDAOWA'
uci set wireless.default_radio2.encryption='psk2'
uci commit wireless
exit 0
WIFIEOF
chmod +x package/base-files/files/etc/uci-defaults/99-custom-wireless
echo "✅ 无线配置完成"

# ======================================
# 6. Dockerman 配置 + 内核选项兜底
# ======================================
echo "--- Dockerman 配置写入 ---"

# 6.1 写入 .config（先处理注释掉的，再追加）
sed -i 's/# CONFIG_PACKAGE_luci-app-dockerman is not set/CONFIG_PACKAGE_luci-app-dockerman=y/' .config
sed -i 's/# CONFIG_PACKAGE_luci-lib-docker is not set/CONFIG_PACKAGE_luci-lib-docker=y/' .config
sed -i 's/# CONFIG_PACKAGE_dockerd is not set/CONFIG_PACKAGE_dockerd=y/' .config
grep -q "CONFIG_PACKAGE_luci-app-dockerman=y" .config || echo "CONFIG_PACKAGE_luci-app-dockerman=y" >> .config
grep -q "CONFIG_PACKAGE_luci-lib-docker=y" .config || echo "CONFIG_PACKAGE_luci-lib-docker=y" >> .config
grep -q "CONFIG_PACKAGE_dockerd=y" .config || echo "CONFIG_PACKAGE_dockerd=y" >> .config

# 6.2 ★ 写入 Docker 必需的内核选项（解决 olddefconfig 报错的根因）
# IPQ60xx 平台默认内核配置可能没开这些，手动写进去
cat >> .config << 'KERNEL_EOF'
CONFIG_KERNEL_NAMESPACES=y
CONFIG_KERNEL_UTS_NS=y
CONFIG_KERNEL_IPC_NS=y
CONFIG_KERNEL_PID_NS=y
CONFIG_KERNEL_NET_NS=y
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_DEVICE=y
CONFIG_KERNEL_CGROUP_FREEZER=y
CONFIG_KERNEL_CGROUP_SCHED=y
CONFIG_KERNEL_CPUSETS=y
CONFIG_KERNEL_MEMCG=y
CONFIG_KERNEL_VETH=y
CONFIG_KERNEL_BRIDGE=y
CONFIG_KERNEL_NETFILTER_XT_MATCH_CONNTRACK=y
CONFIG_KERNEL_NETFILTER_XT_MATCH_IPVS=m
KERNEL_EOF

# 6.3 跑 defconfig（不跑 olddefconfig 了，避免报错中断）
make defconfig
echo "✅ Dockerman 配置完成"

# ======================================
# 6b. 预设 Docker 防火墙规则（防容器无网）
# ======================================
echo "--- 预设 Docker 防火墙规则 ---"
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-docker-firewall << 'DOCKEREOF'
#!/bin/sh
# 防火墙全局转发 ACCEPT
uci set firewall.@defaults[0].forward='ACCEPT'
uci commit firewall
# 禁止 docker 操作 iptables（避免与 OpenWrt 防火墙冲突）
if [ -f /etc/config/dockerd ]; then
    uci set dockerd.dockerd.iptables='0'
    uci commit dockerd
fi
# 创建 docker 防火墙域
if ! uci show firewall | grep -q "firewall.docker"; then
    uci add firewall zone
    uci set firewall.@zone[-1].name='docker'
    uci set firewall.@zone[-1].input='ACCEPT'
    uci set firewall.@zone[-1].output='ACCEPT'
    uci set firewall.@zone[-1].forward='ACCEPT'
    uci add firewall forwarding
    uci set firewall.@forwarding[-1].src='docker'
    uci set firewall.@forwarding[-1].dest='wan'
    uci add firewall forwarding
    uci set firewall.@forwarding[-1].src='lan'
    uci set firewall.@forwarding[-1].dest='docker'
    uci commit firewall
fi
exit 0
DOCKEREOF
chmod +x package/base-files/files/etc/uci-defaults/99-docker-firewall
echo "✅ Docker 防火墙规则预设完成"

# ======================================
# 7. 验证
# ======================================
echo "=== 验证 dockerman（三方源） ==="
if [ -d "package/luci-app-dockerman" ]; then
    echo "✅ package/luci-app-dockerman 存在（来自 kenzok8）"
    ls package/luci-app-dockerman/Makefile 2>/dev/null && echo "   Makefile OK"
else
    echo "❌ package/luci-app-dockerman 不存在！"
fi
echo "=== 验证 .config ==="
for opt in CONFIG_PACKAGE_luci-app-dockerman CONFIG_PACKAGE_luci-lib-docker CONFIG_PACKAGE_dockerd; do
    if grep -q "^${opt}=y" .config; then
        echo "✅ ${opt}=y"
    else
        echo "⚠️  ${opt} 未启用"
    fi
done
echo "=== 检查 OpenClash ==="
[ -d "feeds/luci/applications/luci-app-openclash" ] && echo "✅ OpenClash 存在" || echo "⚠️ OpenClash 不存在"

echo "✅ [DIY-P2] 所有配置完成"
