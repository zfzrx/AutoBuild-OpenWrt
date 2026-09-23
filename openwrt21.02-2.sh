#!/bin/bash
#=================================================
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#=================================================

# 修改默认 wifi
sed -i 's/ssid=OpenWrt/ssid=Xiaomi-Wifi/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
sed -i 's/encryption=none/encryption=psk2/g' package/kernel/mac80211/files/lib/wifi/mac80211.sh
sed -i '/set wireless.default_radio${devidx}.encryption=psk2/a\set wireless.default_radio${devidx}.key=1234567890' package/kernel/mac80211/files/lib/wifi/mac80211.sh

# kernel build info
[ -z $(grep "CONFIG_KERNEL_BUILD_USER=" .config) ] &&
    echo 'CONFIG_KERNEL_BUILD_USER="MOLUN"' >>.config ||
    sed -i 's@\(CONFIG_KERNEL_BUILD_USER=\).*@\1$"MOLUN"@' .config

[ -z $(grep "CONFIG_KERNEL_BUILD_DOMAIN=" .config) ] &&
    echo 'CONFIG_KERNEL_BUILD_DOMAIN="GitHub Actions"' >>.config ||
    sed -i 's@\(CONFIG_KERNEL_BUILD_DOMAIN=\).*@\1$"GitHub Actions"@' .config

# banner / 版本号
YUOS_DATE="$(date +%Y.%m.%d)(4C稳定版)"
BUILD_STRING=${BUILD_STRING:-$YUOS_DATE}
echo -e '\n小渔学长 Build @ '${BUILD_STRING}'\n'  >> package/base-files/files/etc/banner
sed -i '/DISTRIB_REVISION/d' package/base-files/files/etc/openwrt_release
echo "DISTRIB_REVISION=''" >> package/base-files/files/etc/openwrt_release
sed -i '/DISTRIB_DESCRIPTION/d' package/base-files/files/etc/openwrt_release
echo "DISTRIB_DESCRIPTION='小渔学长 Build @ ${BUILD_STRING}'" >> package/base-files/files/etc/openwrt_release

if [ -f feeds/luci/modules/luci-base/luasrc/version.lua ]; then
  sed -i '/luciversion/d' feeds/luci/modules/luci-base/luasrc/version.lua
  echo "luciversion = '${BUILD_STRING}'" >> feeds/luci/modules/luci-base/luasrc/version.lua
fi

# 4C 最小固件：先不要升级 golang（减少失败点）
# 以后要编译带 SSR/passwall 的大包再打开
# rm -rf feeds/packages/lang/golang
# find . -type d -name "golang" -prune -exec rm -rf {} \;
# git clone https://github.com/sbwml/packages_lang_golang -b 25.x feeds/packages/lang/golang

# 强制清掉可能被 feeds/defconfig 重新打开的危险包
sed -i 's/^CONFIG_PACKAGE_luci-app-turboacc-mtk=y/# CONFIG_PACKAGE_luci-app-turboacc-mtk is not set/' .config
sed -i 's/^CONFIG_PACKAGE_luci-app-quickstart=y/# CONFIG_PACKAGE_luci-app-quickstart is not set/' .config
sed -i 's/^CONFIG_PACKAGE_quickstart=y/# CONFIG_PACKAGE_quickstart is not set/' .config
sed -i 's/^CONFIG_PACKAGE_default-settings=y/# CONFIG_PACKAGE_default-settings is not set/' .config
