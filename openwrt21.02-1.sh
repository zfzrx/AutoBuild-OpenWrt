#!/bin/bash
#
# File name: diy-part1.sh
# Description: OpenWrt DIY script part 1 (Before Update feeds)
# 4C 稳定版：不拉 AC2100 默认配置，不覆盖 mt7620 wifi 脚本
#

MODEL="${MODEL:-${GITHUB_EVENT_INPUTS_MODEL:-miwifi-4c}}"

# ---------- 仅 MT7620 机型才拷这些补丁 ----------
if [[ "$MODEL" == "miwifi-3" || "$MODEL" == "miwifi-3x" ]]; then
  cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620a_xiaomi_mi-router-3x.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7620a_xiaomi_mi-router-3x.dts
  cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620a_xiaomi_mi-router-3.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7620a_xiaomi_mi-router-3.dts
  cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620/mt7620.mk $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/mt7620.mk
  cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620/02_network $GITHUB_WORKSPACE/openwrt/target/linux/ramips/mt7620/base-files/etc/board.d/02_network
  cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620/mac80211.sh $GITHUB_WORKSPACE/openwrt/package/kernel/mac80211/files/lib/wifi/mac80211.sh
  cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620/path/ramips $GITHUB_WORKSPACE/openwrt/package/boot/uboot-envtools/files/ramips
  cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7620/path/platform.sh $GITHUB_WORKSPACE/openwrt/target/linux/ramips/mt7620/base-files/lib/upgrade/platform.sh
fi

# MT7621（4A 千兆等）
if [[ "$MODEL" == "miwifi-4a-G" || "$MODEL" == "MI-R3G" || "$MODEL" == "Redmi_AC2100" || "$MODEL" == "Xiaomi_AC2100" || "$MODEL" == "miwifi-4" ]]; then
  cp -rf $GITHUB_WORKSPACE/patchs/xiaomi_mi-router/mt7621_xiaomi_mi-router-4a-gigabit.dts $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/mt7621_xiaomi_mi-router-4a-gigabit.dts || true
fi

# ---------- MT76X8（小米4C）----------
# 若你确认官方源码已有 xiaomi_mi-router-4c，可整段注释掉，避免错误覆盖
if [[ -d "$GITHUB_WORKSPACE/patchs/5.4/mt76x8" ]]; then
  cp -rf $GITHUB_WORKSPACE/patchs/5.4/mt76x8/dts/* $GITHUB_WORKSPACE/openwrt/target/linux/ramips/dts/ || true
  cp -rf $GITHUB_WORKSPACE/patchs/5.4/mt76x8/mt76x8.mk $GITHUB_WORKSPACE/openwrt/target/linux/ramips/image/mt76x8.mk || true
  cp -rf $GITHUB_WORKSPACE/patchs/5.4/mt76x8/02_network $GITHUB_WORKSPACE/openwrt/target/linux/ramips/mt76x8/base-files/etc/board.d/02_network || true
fi

# feeds
sed -i 's|https://git.openwrt.org/project/luci.git;openwrt-21.02|https://github.com/immortalwrt/luci.git;openwrt-21.02|' feeds.conf.default
sed -i 's/git.openwrt.org\/feed\/packages.git;openwrt-21.02/github.com\/coolsnowwolf\/packages.git;master/g' feeds.conf.default

# 4C 先不要 helloworld / small-package（体积和依赖都容易把 64M 搞崩）
# 其它机型需要时再打开
if [[ "$MODEL" != "miwifi-4c" ]]; then
  sed -i '$a src-git helloworld https://github.com/fw876/helloworld.git;master' feeds.conf.default
  sed -i '$a src-git small8 https://github.com/kenzok8/small-package.git;main' feeds.conf.default
fi

# 默认包：4C 不要强塞 default-settings / coremark / 一堆 nathelper
if [[ "$MODEL" == "miwifi-4c" ]]; then
  sed -i 's/dnsmasq/dnsmasq-full firewall iptables/g' include/target.mk
  sed -i 's/ppp-mod-pppoe/ppp ppp-mod-pppoe luci curl ca-certificates/g' include/target.mk
else
  sed -i 's/dnsmasq/dnsmasq-full firewall iptables block-mount coremark kmod-nf-nathelper kmod-nf-nathelper-extra kmod-ipt-raw kmod-ipt-raw6 kmod-tun/g' include/target.mk
  sed -i 's/ppp-mod-pppoe/iptables-mod-tproxy iptables-mod-extra ipset ip-full ppp ppp-mod-pppoe default-settings luci curl ca-certificates/g' include/target.mk
fi

# 软件包：4C 不要 AC2100 的 default-settings
if [[ "$MODEL" == "miwifi-4c" ]]; then
  echo "miwifi-4c: skip AC2100 default-settings / heavy packages"
else
  git clone -b xiaomi-ac2100-21.02 https://github.com/yuos-bit/other package/default-settings
  git clone -b main https://github.com/yuos-bit/other package/main
  git clone -b debug https://github.com/yuos-bit/luci-theme-edge2 package/luci-theme-edge2
  git clone -b tailscale https://github.com/yuos-bit/other package/tailscale
fi

# MT7621 超频（对 4C 无效，保留给其它机型）
if [[ "$MODEL" != "miwifi-4c" ]]; then
  grep "rt_memc_w32(pll,MEMC_REG_CPU_PLL);" ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
  if [ $? -ne 0 ]; then
    echo fix over clock
    sed -i 's/-111,49 +111,89/-111,49 +111,93/' ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
    sed -i 's/u32 xtal_clk, cpu_clk, bus_clk;/u32 xtal_clk, cpu_clk, bus_clk,i;/' ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
    sed -i '157i+		pll &= ~(0x7ff);' ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
    sed -i '158i+		pll |=  (0x362);' ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
    sed -i '159i+		rt_memc_w32(pll,MEMC_REG_CPU_PLL);' ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
    sed -i '160i+		for(i=0;i<1024;i++);' ./target/linux/ramips/patches-5.4/102-mt7621-fix-cpu-clk-add-clkdev.patch
  fi
fi
