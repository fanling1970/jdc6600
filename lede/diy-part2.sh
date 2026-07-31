#!/bin/bash
# diy-part2.sh - 在 feeds install 之后执行
echo "=== [DIY-P2] 开始配置第三方包和系统设置 ==="

# ======================================
# 1. 更新并安装指定 feeds
# ======================================
echo "--- 更新 kenzo & small feeds ---"
./scripts/feeds update kenzo small

echo "--- 安装 kenzo 包 (Argon/iStore/Dockerman) ---"
./scripts/feeds install -f -p kenzo luci-theme-argon
./scripts/feeds install -f -p kenzo luci-app-argon-config
./scripts/feeds install -f -p kenzo luci-app-istorex
./scripts/feeds install -f -p kenzo luci-app-quickstart
./scripts/feeds install -f -p kenzo luci-app-store
./scripts/feeds install -f -p kenzo luci-app-dockerman

echo "--- 安装 small 包 (SSR+/OpenClash) ---"
./scripts/feeds install -f -p small luci-app-ssr-plus
./scripts/feeds install -f -p small luci-app-openclash

echo "✅ feeds 安装完成"

# ======================================
# 2. 手动克隆 kenzo 源中不存在的包
# ======================================
echo "--- 克隆 luci-lib-docker (Dockerman 依赖) ---"
# luci-lib-docker 不在 kenzo 源中，从独立仓库获取
git clone --depth=1 https://github.com/lisaac/luci-lib-docker.git package/luci-lib-docker || {
    echo "❌ luci-lib-docker 拉取失败"
    exit 1
}
echo "✅ luci-lib-docker 克隆完成"

echo "--- 克隆 Athena LED 控制插件 ---"
# luci-app-athena-led 不在 kenzo 源中，从原始仓库获取
git clone --depth=1 https://github.com/NONGFAH/luci-app-athena-led package/luci-app-athena-led || {
    echo "❌ Athena LED 插件拉取失败"
    exit 1
}
chmod +x package/luci-app-athena-led/root/etc/init.d/athena_led
chmod +x package/luci-app-athena-led/root/usr/sbin/athena-led
echo "✅ Athena LED 插件克隆完成"

# ======================================
# 3. 基础系统设置修改
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
# 4. 清理冲突包
# ======================================
echo "--- 清理冲突包 ---"
rm -rf feeds/luci/applications/luci-app-istorex 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-quickstart 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-store 2>/dev/null || true
rm -rf feeds/luci/libraries/luci-lib-taskd 2>/dev/null || true
rm -rf feeds/luci/applications/quickstart 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-openclash 2>/dev/null || true
rm -rf feeds/luci/applications/luci-app-ssr-plus 2>/dev/null || true
# 清理 Lean 自带的 dockerman/argon，确保使用 kenzo/手动版本
rm -rf feeds/luci/applications/luci-app-dockerman 2>/dev/null || true
rm -rf feeds/luci/themes/luci-theme-argon 2>/dev/null || true
echo "✅ 冲突包清理完成"

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
echo "=== 验证 feeds 安装状态 ==="
ls -la package/feeds/kenzo/ 2>/dev/null | grep -E "(argon|istorex|dockerman)" || echo "⚠️ kenzo 包未找到"
ls -la package/feeds/small/ 2>/dev/null | grep -E "(ssr-plus|openclash)" || echo "⚠️ small 包未找到"
echo "=== 验证手动克隆包 ==="
[ -d "package/luci-lib-docker" ] && echo "✅ luci-lib-docker 存在" || echo "❌ luci-lib-docker 缺失"
[ -d "package/luci-app-athena-led" ] && echo "✅ athena-led 存在" || echo "❌ athena-led 缺失"
echo "=== 验证 feeds 源 ==="
grep -E "(kenzo|small)" feeds.conf.default
echo "✅ [DIY-P2] 所有配置完成"
