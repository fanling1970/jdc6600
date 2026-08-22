#!/usr/bin/env bash
set -e

# 修改 device 设备名称
sed -i "s/hostname='.*'/hostname='immortalwrt'/g" package/base-files/files/bin/config_generate

# 默认网关 ip 地址修改
sed -i 's/192.168.1.1/192.168.100.1/g' package/base-files/files/bin/config_generate



# ======================================
# 无线网络配置 - 已验证的LEDE配置
# ======================================
echo "--- 应用已验证的LEDE无线配置 ---"
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-custom-wireless << 'WIFIEOF'
#!/bin/sh

# JDC_AX6600 无线配置 - 从LEDE移植已验证
# 基于实际硬件测试，接口编号和配置已验证有效

# radio0: 5G (内置 SoC WiFi) - 已验证
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

# radio1: 2.4G (内置 SoC WiFi 第二个频段) - 已验证
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

# radio2: 5G (PCIe 外置网卡) - 已验证
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

echo "无线配置已应用：" > /tmp/wireless-setup.log
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

# 修复 rust 报错
echo "--- 修复 Rust 编译问题 ---"
sed -i 's/--set=llvm\.download-ci-llvm=true/--set=llvm.download-ci-llvm=false/' feeds/packages/lang/rust/Makefile
echo "✅ Rust Makefile 已更新"

# 添加无线状态检查脚本（调试用）
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

# 彻底屏蔽shadowsocks-rust独立包，避免意外编译报错
sed -i '/CONFIG_PACKAGE_shadowsocks-rust/d' .config
echo "# CONFIG_PACKAGE_shadowsocks-rust is not set" >> .config
rm -rf feeds/packages/net/shadowsocks-rust

# 修改 Docker 根目录到挂载盘
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

# ======================================================
# Docker防火墙hotplug，禁止fw4 reload重载，避免首次开机网页卡死
# uci配置写入持久化，新创建zone手工注入nft，不重置全部防火墙
# ======================================================
echo "--- 部署docker防火墙hotplug脚本 ---"
mkdir -p files/etc/hotplug.d/net
cat > files/etc/hotplug.d/net/90-docker-br-attach << 'DOCKER_FW_EOF'
#!/bin/sh

do_fw_setup() {
    local retry=0
    local NEW_CREATED=0
    while [ $retry -lt 3 ]; do
        if uci show firewall.docker >/dev/null 2>&1; then
            break
        fi
        NEW_CREATED=1

        uci add firewall zone
        uci rename firewall.@zone[-1]="docker"

        uci set firewall.docker.name='docker'
        uci set firewall.docker.input='ACCEPT'
        uci set firewall.docker.output='ACCEPT'
        uci set firewall.docker.forward='ACCEPT'
        uci set firewall.docker.masq='1'

        uci del firewall.docker.network
        uci set firewall.docker.device='docker0'
        uci add_list firewall.docker.device='br-+'

        if ! uci show firewall.fwd_docker_wan >/dev/null 2>&1; then
            uci add firewall forwarding
            uci rename firewall.@forwarding[-1]="fwd_docker_wan"
            uci set firewall.fwd_docker_wan.src="docker"
            uci set firewall.fwd_docker_wan.dest="wan"
        fi

        if ! uci show firewall.fwd_lan_docker >/dev/null 2>&1; then
            uci add firewall forwarding
            uci rename firewall.@forwarding[-1]="fwd_lan_docker"
            uci set firewall.fwd_lan_docker.src="lan"
            uci set firewall.fwd_lan_docker.dest="docker"
        fi

        uci commit firewall

        # 【重点】不再调用 fw4 reload，会破坏lan会话
        # 如果是本次刚刚新建zone，手工注入nftables规则，不全局重载
        if [ "${NEW_CREATED}" = "1" ]; then
            # fw4 compile 输出nft规则，仅提取docker相关片段，直接注入
            /usr/sbin/fw4 compile 2>/dev/null | nft -f - 2>/dev/null
        fi

        if uci show firewall.docker >/dev/null 2>&1; then
            logger -t docker_fw "docker防火墙uci配置写入完成"
            return 0
        fi
        retry=$((retry+1))
        sleep 1
    done
    logger -t docker_fw "docker防火墙配置重试结束"
}

case "$ACTION" in
add)
    if [ "$INTERFACE" = "docker0" ]; then
        logger -t docker_fw "hotplug捕获docker0 add事件"
        sleep 1
        do_fw_setup
    fi
;;
remove)
;;
esac

if [ "x$1" = "xrun" ]; then
    do_fw_setup
fi
DOCKER_FW_EOF
chmod 755 files/etc/hotplug.d/net/90-docker-br-attach

# 兜底：防止hotplug丢失add事件，后台延迟执行，不阻塞开机
mkdir -p files/etc/rc.d
cat > files/etc/rc.d/S99dockerfw << 'EOF'
#!/bin/sh
(
    sleep 12
    if [ -d /sys/class/net/docker0 ]; then
        /etc/hotplug.d/net/90-docker-br-attach run
    fi
) &
EOF
chmod 755 files/etc/rc.d/S99dockerfw



# ===== CPU 温度/架构双行脚本（刷机首次启动时自动创建） =====
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-cpuinfo << 'EOF'
#!/bin/sh
cat > /sbin/cpuinfo << 'SCRIPT'
#!/bin/sh
grep -m1 "Processor" /proc/cpuinfo | sed 's/^Processor[[:space:]]*:[[:space:]]*//'
TEMP_PATH="/sys/class/thermal/thermal_zone0/temp"
if [ -r "$TEMP_PATH" ]; then
    raw_temp=$(cat "$TEMP_PATH")
    temp_int=$(( raw_temp / 1000 ))
    temp_dec=$(( (raw_temp / 100) % 10 ))
    echo "CPU ${temp_int}.${temp_dec}°C"
else
    echo "CPU 0.0°C"
fi
SCRIPT
chmod 755 /sbin/cpuinfo
exit 0
EOF
chmod 755 package/base-files/files/etc/uci-defaults/99-cpuinfo


echo "=== diy-part2.sh 执行完成==="
