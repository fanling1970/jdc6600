#!/bin/bash
# diy-part2.sh - 在 feeds install 之后执行
echo "=== [DIY-P2] 开始配置第三方包和系统设置 ==="

# ======================================
# 0. Dockerman 冲突预处理（关键！）
# ======================================
echo "--- Dockerman 冲突预处理 ---"

# 0.1 再次保险：清除任何来源的旧 dockerman 残留
rm -rf package/luci-app-dockerman package/luci-lib-docker 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-dockerman 2>/dev/null || true
rm -rf feeds/luci/libs/luci-lib-docker 2>/dev/null || true
rm -rf feeds/kenzo/luci-app-dockerman 2>/dev/null || true
rm -rf feeds/kenzo/luci-lib-docker 2>/dev/null || true

# 0.2 禁用 luci-app-docker（与 dockerman 互斥，是各种怪问题的根源）
if [ -f .config ]; then
    sed -i '/CONFIG_PACKAGE_luci-app-docker=y/d' .config
    sed -i '/CONFIG_PACKAGE_luci-app-docker=m/d' .config
    # 同时清掉被 defconfig 注释掉的残留
    sed -i '/# CONFIG_PACKAGE_luci-app-docker is not set/d' .config
fi
echo "✅ Dockerman 冲突预处理完成"

# ======================================
# 1. 克隆第三方包（不在 feeds 中的包）
# ======================================
echo "--- 克隆 Argon 主题 ---"
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon || {
    echo "❌ Argon 主题拉取失败"
    exit 1
}

echo "--- 克隆 Argon 配置插件 ---"
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config || {
    echo "❌ Argon 配置插件拉取失败"
    exit 1
}
echo "✅ Argon 主题克隆完成"

echo "--- 克隆 Athena LED 控制插件 ---"
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led || {
    echo "❌ Athena LED 插件拉取失败"
    exit 1
}
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led
chmod +x package/luci-app-athena-led/root/usr/sbin/athena-led
echo "✅ Athena LED 插件克隆完成"

# ======================================
# 2. 基础系统设置修改
# ======================================
echo "--- 修改基础系统设置 ---"

# 修改主机名
sed -i "s/hostname='.*'/hostname='LEDE'/g" package/base-files/files/bin/config_generate

# 修改版本描述
sed -i "s/DISTRIB_DESCRIPTION='*.*'/DISTRIB_DESCRIPTION='OpenWrt-$(date +%Y%m%d)'/g" package/lean/default-settings/files/zzz-default-settings   
sed -i "s/DISTRIB_REVISION='*.*'/DISTRIB_REVISION=' By J.Y'/g" package/lean/default-settings/files/zzz-default-settings

# 修改默认网关 IP
sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate

# 清除默认密码
sed -i '/V4UetPzk$CYXluq4wUazHjmCDBCqXF/d' package/lean/default-settings/files/zzz-default-settings

# 添加 iStore 频道信息
if ! grep -q "istore.channel" package/lean/default-settings/files/zzz-default-settings; then
    sed -i "/^uci commit istore/i uci set istore.istore.channel='OpenWrt'" \
        package/lean/default-settings/files/zzz-default-settings
fi

echo "✅ 基础系统设置修改完成"

# ======================================
# 3. 清理冲突包（保留源码自带 OpenClash）
# ======================================
echo "--- 清理冲突包 ---"

rm -rf feeds/luci/applications/luci-app-istorex 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-quickstart 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-store 2>/dev/null || true
rm -rf feeds/luci/libraries/luci-lib-taskd 2>/dev/null || true
rm -rf feeds/luci/applications/quickstart 2>/dev/null || true

echo "✅ 冲突包清理完成（保留源码 OpenClash）"

# ======================================
# 4. 更新并安装特定 feeds（含三方 dockerman）
# ======================================
echo "--- 更新 feeds ---"
./scripts/feeds update helloworld istore nas nas_luci kenzo

echo "--- 安装 feeds ---"
# 安装 helloworld（SSR）
./scripts/feeds install -a -p helloworld

# 安装 iStore
./scripts/feeds install -d y -p istore luci-app-store

# 安装 NAS 插件
./scripts/feeds install -a -p nas
./scripts/feeds install -a -p nas_luci

# ★ 安装三方 dockerman（来自 kenzo 源）
echo "--- 安装三方 dockerman（kenzo 源）---"
./scripts/feeds install -p kenzo luci-app-dockerman
./scripts/feeds install -p kenzo luci-lib-docker
# dockerd（可能在 kenzo 或 packages 里）
./scripts/feeds install dockerd 2>/dev/null || true
./scripts/feeds install containerd 2>/dev/null || true
./scripts/feeds install runc 2>/dev/null || true
echo "✅ 三方 dockerman 安装完成"

echo "✅ feeds 安装完成"

# ======================================
# 5. 无线网络配置
# ======================================
echo "--- 配置无线网络 ---"
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-wireless << 'WIFIEOF'
#!/bin/sh

# JDC_AX6600 无线配置
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
# 6. ★ Dockerman 强制启用（defconfig 之后硬写，解决被清问题）
# ======================================
echo "--- Dockerman 强制启用 ---"

# 6.1 先跑一次 defconfig，让系统清理完不满足的依赖
make defconfig

# 6.2 强制写入 dockerman（无论之前发生了什么）
# 处理被注释掉的情况
sed -i 's/# CONFIG_PACKAGE_luci-app-dockerman is not set/CONFIG_PACKAGE_luci-app-dockerman=y/' .config
sed -i 's/# CONFIG_PACKAGE_luci-lib-docker is not set/CONFIG_PACKAGE_luci-lib-docker=y/' .config
sed -i 's/# CONFIG_PACKAGE_dockerd is not set/CONFIG_PACKAGE_dockerd=y/' .config

# 如果还是没有这一行，就追加
grep -q "CONFIG_PACKAGE_luci-app-dockerman=y" .config || echo "CONFIG_PACKAGE_luci-app-dockerman=y" >> .config
grep -q "CONFIG_PACKAGE_luci-lib-docker=y" .config || echo "CONFIG_PACKAGE_luci-lib-docker=y" >> .config
grep -q "CONFIG_PACKAGE_dockerd=y" .config || echo "CONFIG_PACKAGE_dockerd=y" >> .config

# 再次保险：确认 luci-app-docker 被禁用
sed -i '/CONFIG_PACKAGE_luci-app-docker=y/d' .config
sed -i '/CONFIG_PACKAGE_luci-app-docker=m/d' .config

# 6.3 再次 olddefconfig，让新加的包自动拉取依赖
make olddefconfig

echo "✅ Dockerman 强制启用完成"

# ======================================
# 6b. ★ 预设防火墙规则（解决 OpenWrt + Docker 容器无网络问题）
# ======================================
echo "--- 预设 Docker 防火墙规则 ---"
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-docker-firewall << 'DOCKEREOF'
#!/bin/sh
# 解决 OpenWrt + Docker 容器无网络的经典问题
# 刷机后自动执行一次

# 方案A：防火墙全局转发设为 ACCEPT
uci set firewall.@defaults[0].forward='ACCEPT'
uci commit firewall

# 方案B：禁止 docker 操作 iptables（避免与 OpenWrt fw3/fw4 规则互相覆盖）
# 这是 IPQ60xx + OpenWrt 23.05 上容器无网最常见的原因
if [ -f /etc/config/dockerd ]; then
    uci set dockerd.dockerd.iptables='0'
    uci commit dockerd
fi

# 方案C：创建 docker 防火墙域
if ! uci show firewall | grep -q "firewall.docker"; then
    # docker 区域
    uci add firewall zone
    uci set firewall.@zone[-1].name='docker'
    uci set firewall.@zone[-1].input='ACCEPT'
    uci set firewall.@zone[-1].output='ACCEPT'
    uci set firewall.@zone[-1].forward='ACCEPT'
    
    # docker -> wan（容器访问外网）
    uci add firewall forwarding
    uci set firewall.@forwarding[-1].src='docker'
    uci set firewall.@forwarding[-1].dest='wan'
    
    # lan -> docker（LAN 访问容器服务）
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
# 7. 验证配置
# ======================================
echo "=== 验证 package/ 状态 ==="
ls -la package/ | grep -E "(argon|athena|helloworld)"
echo "=== 验证 dockerman 来源 ==="
if [ -d "feeds/kenzo/luci-app-dockerman" ]; then
    echo "✅ 三方 dockerman 已从 kenzo 源安装"
    ls -la feeds/kenzo/luci-app-dockerman/ 2>/dev/null | head -5
else
    echo "❌ kenzo 源中未找到 dockerman，请检查 kenzo 源"
fi
echo "=== 验证 .config 关键选项 ==="
for opt in CONFIG_PACKAGE_luci-app-dockerman CONFIG_PACKAGE_luci-lib-docker CONFIG_PACKAGE_dockerd CONFIG_PACKAGE_containerd CONFIG_PACKAGE_runc; do
    val=$(grep "^${opt}" .config 2>/dev/null | head -1)
    if echo "$val" | grep -q "=y"; then
        echo "✅ ${opt}=y"
    elif echo "$val" | grep -q "=m"; then
        echo "ℹ️  ${opt}=m (模块)"
    else
        echo "⚠️  ${opt} 未启用 (当前: '${val}')"
    fi
done
if grep -q "CONFIG_PACKAGE_luci-app-docker=y" .config; then
    echo "❌ 警告：luci-app-docker 仍被启用，与 dockerman 冲突！"
else
    echo "✅ luci-app-docker 已禁用（无冲突）"
fi
echo "=== 检查 OpenClash ==="
if [ -d "feeds/luci/applications/luci-app-openclash" ]; then
    echo "✅ 源码自带 OpenClash 存在"
else
    echo "⚠️ 源码自带 OpenClash 不存在"
fi

echo "✅ [DIY-P2] 所有配置完成"
