#!/bin/bash
# diy-part2.sh - 在 feeds install 之后执行
echo "=== [DIY-P2] 开始配置第三方包和系统设置 ==="

# ======================================
# 1. 克隆第三方包
# ======================================
echo "--- 克隆 Argon 主题 ---"
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon.git package/luci-theme-argon || {
    echo "❌ Argon 主题拉取失败"; exit 1
}

echo "--- 克隆 Argon 配置插件 ---"
git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config.git package/luci-app-argon-config || {
    echo "❌ Argon 配置插件拉取失败"; exit 1
}
echo "✅ Argon 主题克隆完成"

echo "--- 克隆 Athena LED 控制插件 ---"
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led || {
    echo "❌ Athena LED 插件拉取失败"; exit 1
}
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led
chmod +x package/luci-app-athena-led/root/usr/sbin/athena-led
echo "✅ Athena LED 插件克隆完成"

echo "--- 克隆 Dockerman (lisaac) ---"
git clone --depth=1 https://github.com/lisaac/luci-lib-docker.git package/luci-lib-docker || {
    echo "❌ luci-lib-docker 拉取失败"; exit 1
}
git clone --depth=1 https://github.com/lisaac/luci-app-dockerman.git package/luci-app-dockerman || {
    echo "❌ luci-app-dockerman 拉取失败"; exit 1
}
echo "✅ Dockerman 克隆完成"

echo "--- 克隆 OpenClash (vernesong 原版) ---"
git clone --depth=1 https://github.com/vernesong/OpenClash.git package/luci-app-openclash || {
    echo "❌ OpenClash 拉取失败"; exit 1
}
echo "✅ OpenClash 克隆完成"

# ======================================
# 2. 基础系统设置修改
# ======================================
echo "--- 修改基础系统设置 ---"

sed -i "s/hostname='.*'/hostname='LEDE'/g" package/base-files/files/bin/config_generate

sed -i "s/DISTRIB_DESCRIPTION='*.*'/DISTRIB_DESCRIPTION='OpenWrt-$(date +%Y%m%d)'/g" package/lean/default-settings/files/zzz-default-settings
sed -i "s/DISTRIB_REVISION='*.*'/DISTRIB_REVISION=' By J.Y'/g" package/lean/default-settings/files/zzz-default-settings

sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate

sed -i '/V4UetPzk$CYXluq4wUazHjmCDBCqXF/d' package/lean/default-settings/files/zzz-default-settings

if ! grep -q "istore.channel" package/lean/default-settings/files/zzz-default-settings; then
    sed -i "/^uci commit istore/i uci set istore.istore.channel='OpenWrt'" \
        package/lean/default-settings/files/zzz-default-settings
fi

echo "✅ 基础系统设置修改完成"

# ======================================
# 3. 清理冲突包
# ======================================
echo "--- 清理冲突包 ---"
# 删除 Lean 源码自带的同名包，防止与手动克隆版本冲突
rm -rf feeds/luci/applications/luci-app-dockerman 2>/dev/null || true
rm -rf feeds/luci/libraries/luci-lib-docker 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-openclash 2>/dev/null || true
# iStore 相关冲突包
rm -rf feeds/luci/applications/luci-app-istorex 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-quickstart 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-store 2>/dev/null || true
rm -rf feeds/luci/libraries/luci-lib-taskd 2>/dev/null || true
rm -rf feeds/luci/applications/quickstart 2>/dev/null || true
echo "✅ 冲突包清理完成"

# ======================================
# 4. 更新并安装 feeds（helloworld/istore/nas）
# ======================================
echo "--- 更新 feeds ---"
./scripts/feeds update helloworld istore nas nas_luci

echo "--- 安装 feeds ---"
./scripts/feeds install -a -p helloworld
./scripts/feeds install -d y -p istore luci-app-store
./scripts/feeds install -a -p nas
./scripts/feeds install -a -p nas_luci
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
# 6. 验证配置
# ======================================
echo "=== 验证手动克隆包 ==="
for pkg in luci-theme-argon luci-app-argon-config luci-app-athena-led luci-lib-docker luci-app-dockerman luci-app-openclash; do
    [ -d "package/$pkg" ] && echo "✅ $pkg 存在" || echo "❌ $pkg 缺失"
done
echo "=== 验证 feeds 源 ==="
grep -E "(helloworld|istore|nas)" feeds.conf.default
echo "=== 确认源码自带包已清除 ==="
[ ! -d "feeds/luci/applications/luci-app-dockerman" ] && echo "✅ 源码 dockerman 已清除" || echo "⚠️ 源码 dockerman 仍存在"
[ ! -d "feeds/luci/applications/luci-app-openclash" ] && echo "✅ 源码 openclash 已清除" || echo "⚠️ 源码 openclash 仍存在"
echo "✅ [DIY-P2] 所有配置完成"
