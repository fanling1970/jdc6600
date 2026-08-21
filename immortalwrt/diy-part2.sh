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
# 集成 docker防火墙hotplug脚本，使用全局files覆盖，不改动package源码
# 放弃 procd/hook.d（ImmortalWrt存在事件丢失bug），改用dockerd原生 procd_post_start
# ======================================================
echo "--- 部署docker防火墙hotplug脚本 ---"
mkdir -p files/etc/hotplug.d/net
cat > files/etc/hotplug.d/net/90-docker-br-attach << 'DOCKER_FW_EOF'
#!/bin/sh

do_fw_setup() {
    # 创建/更新 docker zone，使用 device 匹配（fw4 br‑+通配）
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
    uci set firewall.docker.device='docker0'
    uci add_list firewall.docker.device='br-+'

    # 转发规则 docker→wan
    if ! uci show firewall.fwd_docker_wan >/dev/null 2>&1; then
        uci add firewall forwarding
        uci rename firewall.@forwarding[-1]="fwd_docker_wan"
        uci set firewall.fwd_docker_wan.src="docker"
        uci set firewall.fwd_docker_wan.dest="wan"
    fi

    # 转发规则 lan→docker
    if ! uci show firewall.fwd_lan_docker >/dev/null 2>&1; then
        uci add firewall forwarding
        uci rename firewall.@forwarding[-1]="fwd_lan_docker"
        uci set firewall.fwd_lan_docker.src="lan"
        uci set firewall.fwd_lan_docker.dest="docker"
    fi

    uci commit firewall
    # fw4增量重载，禁止完整firewall服务重启，避免首次开机网页卡死
    fw4 reload 2>/dev/null || true
}

# 网卡热插拔事件触发
case "$ACTION" in
add|remove)
    [ "$INTERFACE" = "docker" ] && do_fw_setup
;;
esac

# 支持外部调用：/etc/hotplug.d/net/90-docker-br-attach run
if [ "x$1" = "xrun" ]; then
    do_fw_setup
fi
DOCKER_FW_EOF
chmod 755 files/etc/hotplug.d/net/90-docker-br-attach

echo "--- 生成dockerd post_start回调脚本 ---"
mkdir -p files/etc/init.d
cat > files/etc/init.d/docker_poststart << 'DOCKER_POST_EOF'
#!/bin/sh
# dockerd procd_post_start 回调脚本

wait_cnt=0
while [ ! -d /sys/class/net/docker0 ] && [ $wait_cnt -lt 8 ]; do
    sleep 1
    wait_cnt=$((wait_cnt+1))
done

if [ -d /sys/class/net/docker0 ]; then
    /etc/hotplug.d/net/90-docker-br-attach run
fi
DOCKER_POST_EOF
chmod 755 files/etc/init.d/docker_poststart

# 直接预置dockerd配置到固件rootfs，刷机第一次开机就携带procd_post_start
mkdir -p files/etc/config
cat > files/etc/config/dockerd <<'DOCKERD_CFG'
config globals 'globals'
        option procd_post_start '/etc/init.d/docker_poststart'
DOCKERD_CFG
echo "=== diy-part2.sh 执行完成==="
