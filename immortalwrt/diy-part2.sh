#!/bin/bash
#
# Copyright (c) 2019-2020 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#

# ====================== 1.基础系统设置 ======================
# 修改 device 设备名称
sed -i "s/hostname='.*'/hostname='immortalwrt'/g" package/base-files/files/bin/config_generate

# 默认网关 ip 地址修改
sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate


# ======================================
# 无线网络配置 - JDC_AX6600
# ======================================
echo "--- 应用无线配置 ---"
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-wireless << 'WIFIEOF'
#!/bin/sh

# JDC_AX6600 无线配置
# radio0: 5G SoC
uci set wireless.radio0.disabled='0'
uci set wireless.radio0.channel='149'
uci set wireless.radio0.band='5g'
uci set wireless.radio0.htmode='HE80'
uci set wireless.radio0.country='CN'
uci set wireless.radio0.cell_density='0'
uci set wireless.default_radio0.ssid='JDC_AX6600_5G'
uci set wireless.default_radio0.key='BUZHIDAOWA'
uci set wireless.default_radio0.encryption='psk2'
uci set wireless.default_radio0.network='lan'

# radio1: 2.4G SoC
uci set wireless.radio1.disabled='0'
uci set wireless.radio1.channel='6'
uci set wireless.radio1.band='2g'
uci set wireless.radio1.htmode='HT40'
uci set wireless.radio1.country='CN'
uci set wireless.radio1.cell_density='0'
uci set wireless.default_radio1.ssid='JDC_AX6600_2.4G'
uci set wireless.default_radio1.key='BUZHIDAOWA'
uci set wireless.default_radio1.encryption='psk2'
uci set wireless.default_radio1.network='lan'

# radio2: 5G PCIe外置网卡
uci set wireless.radio2.disabled='0'
uci set wireless.radio2.channel='44'
uci set wireless.radio2.band='5g'
uci set wireless.radio2.htmode='HE160'
uci set wireless.radio2.country='CN'
uci set wireless.radio2.cell_density='0'
uci set wireless.default_radio2.ssid='JDC_AX6600_5G2'
uci set wireless.default_radio2.key='BUZHIDAOWA'
uci set wireless.default_radio2.encryption='psk2'
uci set wireless.default_radio2.network='lan'

uci commit wireless

echo "无线配置已应用" > /tmp/wireless-setup.log
uci show wireless | grep -E "(radio[0-9]\.(disabled|channel|band|htmode)|default_radio[0-9]\.ssid)" >> /tmp/wireless-setup.log
chmod 600 /etc/config/wireless 2>/dev/null

exit 0
WIFIEOF

chmod +x package/base-files/files/etc/uci-defaults/99-custom-wireless
echo "✅ LEDE无线配置已移植"

# 修复 jdCloud ax6600 无限重启
echo "--- 修复 jdCloud ax6600 无限重启 ---"
rm -rf package/kernel/mac80211/patches/nss/ath11k/999-900-bss-transition-handling.patch
echo "✅ 已删除可能导致重启的补丁"

# 修复 rust 编译问题
echo "--- 修复 Rust 编译问题 ---"
sed -i 's/--set=llvm\.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/' feeds/packages/lang/rust/Makefile
echo "✅ Rust Makefile 已更新"

# 添加无线状态检查脚本
echo "--- 添加无线状态检查脚本 ---"
mkdir -p package/base-files/files/usr/bin
cat > package/base-files/files/usr/bin/wifi-status << 'STATUSEOF'
#!/bin/sh
echo "=== JDC_AX6600 无线状态检查 ==="
echo "编译时间: $(date)"
echo "固件版本: $(cat /etc/openwrt_release 2>/dev/null | grep DISTRIB_DESCRIPTION | cut -d= -f2)"
echo ""
echo "1. 无线接口列表:"
iwinfo 2>/dev/null | grep -E "ESSID|Mode|Channel" || echo "iwinfo未安装或无线未启动"
echo ""
echo "2. UCI无线配置:"
uci show wireless | grep -v "key=" | grep -v "passphrase="
echo ""
echo "3. 无线物理设备:"
ls -la /sys/class/ieee80211/ 2>/dev/null && {
    for phy in /sys/class/ieee80211/*; do
        echo "设备: $(basename $phy)"
        [ -f $phy/name ] && echo "  名称: $(cat $phy/name)"
        [ -f $phy/macaddress ] && echo "  MAC: $(cat $phy/macaddress)"
    done
}
echo ""
echo "4. 无线网络状态:"
ifconfig | grep -A1 "wlan"
STATUSEOF

chmod +x package/base-files/files/usr/bin/wifi-status
echo "✅ 无线状态检查脚本已添加"

# 彻底屏蔽shadowsocks-rust独立包
sed -i '/CONFIG_PACKAGE_shadowsocks-rust/d' .config
echo "# CONFIG_PACKAGE_shadowsocks-rust is not set" >> .config
rm -rf feeds/packages/net/shadowsocks-rust

# 修改 Docker 根目录到挂载盘
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-docker-data << 'EOF'
#!/bin/sh
mkdir -p /mnt/mmcblk0p27/docker
if uci get dockerd.globals >/dev/null 2>&1; then
    uci set dockerd.globals.data_root="/mnt/mmcblk0p27/docker"
else
    uci set dockerd.@globals[0].data_root="/mnt/mmcblk0p27/docker"
fi
uci commit dockerd
exit 0
EOF
chmod 755 package/base-files/files/etc/uci-defaults/99-docker-data


# ====================== 生成全部自定义文件到openwrt/files ======================
echo "==== 生成自定义文件 openwrt/files ===="
mkdir -p files/etc/hotplug.d/net
mkdir -p files/etc/uci-defaults
mkdir -p files/usr/share/rpcd/ucode

# docker网桥hotplug脚本
cat > files/etc/hotplug.d/net/90-docker-br-attach <<'EOF'
#!/bin/sh
case "$ACTION" in
    add|remove|reload)
        if ! uci show firewall.docker >/dev/null 2>&1; then
            uci add firewall zone
            uci rename firewall.@zone[-1]="docker"
        fi

        uci set firewall.docker.name='docker'
        uci set firewall.docker.input='ACCEPT'
        uci set firewall.docker.output='ACCEPT'
        uci set firewall.docker.forward='ACCEPT'
        uci set firewall.docker.masq='1'

        uci del firewall.docker.network
        uci add_list firewall.docker.network='docker'

        for brif in $(ls /sys/class/net | grep -E '^br‑'); do
            uci add_list firewall.docker.network="$brif"
        done

        uci commit firewall
        /etc/init.d/firewall reload
    ;;
esac
EOF
chmod 755 files/etc/hotplug.d/net/90-docker-br-attach

# 去重docker zone
cat > files/etc/uci-defaults/98-dedup-docker-zone <<'EOF'
#!/bin/sh
while uci show firewall.@zone | grep -q '\.name=docker'; do
    idx=$(uci show firewall.@zone | grep '\.name=docker' | head -n1 | cut -d'[' -f2 | cut -d']' -f1)
    if [ -n "$idx" ]; then
        uci del firewall.@zone["$idx"]
    fi
done
uci commit firewall
EOF
chmod 755 files/etc/uci-defaults/98-dedup-docker-zone

# 初始化docker防火墙zone
cat > files/etc/uci-defaults/99-init-docker-fw <<'EOF'
#!/bin/sh
if ! uci show firewall.docker >/dev/null 2>&1; then
    uci add firewall zone
    uci rename firewall.@zone[-1] docker
fi
uci set firewall.docker.name="docker"
uci set firewall.docker.input="ACCEPT"
uci set firewall.docker.output="ACCEPT"
uci set firewall.docker.forward="ACCEPT"
uci set firewall.docker.masq="1"
uci del firewall.docker.network
uci add_list firewall.docker.network="docker"
uci commit firewall
exit 0
EOF
chmod 755 files/etc/uci-defaults/99-init-docker-fw

# autocore.uc ipq60xx【状态‑概况】页面温度修复
cat > files/usr/share/rpcd/ucode/autocore.uc <<'EOF'
// ipq60xx cpu temp fix
let fs = require("fs");
let temp = 0;
try {
    let raw = fs.read_file("/sys/class/thermal/thermal_zone1/temp");
    temp = Math.floor(Number(raw)/1000);
} catch(err) {
    try {
        let raw = fs.read_file("/sys/class/thermal/thermal_zone0/temp");
        temp = Math.floor(Number(raw)/1000);
    } catch(err2) {
        temp = 0;
    }
}
return {
    cpu_temp: temp
};
EOF
chmod 644 files/usr/share/rpcd/ucode/autocore.uc

echo "✅ diy‑part2.sh 全部自定义文件生成完毕"
echo "=== diy-part2.sh 执行完成==="
