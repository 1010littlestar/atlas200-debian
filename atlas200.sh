#!/bin/sh
echo davinci device startup
date

#$(pwd)   : install_path/HiAI/driver/boot
#homepath : install_path/HiAI
homepath=/usr/local/HiAI
kopath=$homepath/driver/host
toolspath=$homepath/driver/tools
username=HwHiAiUser
usergroup=HwHiAiUser

echo "startup insmod atlas200 drivers"

if [ ! -n "$(lsmod | grep drv_seclib_host)" ] ; then
    insmod $kopath/drv_seclib_host.ko
    insmod $kopath/drv_pcie_host.ko type="3559"
    insmod $kopath/drv_devmng_host.ko
    insmod $kopath/drv_pcie_hdc_host.ko
    insmod $kopath/drv_pcie_vnic_host.ko
fi

echo "startup hdcd"

hdc_cdev_check()
{
	for idx in $(seq 1 30)
	do
		if [ -e /dev/hisi_hdc ];then
			chmod -f 640 /dev/hisi_hdc
			chown -f $username:$usergroup /dev/hisi_hdc
			break
		fi
		sleep 1
	done
}

directory_check() {
	path=$1
	if [ ! -d $path ];then
		mkdir -p $path
	fi

	chmod 750 $path
	chown $username:$usergroup $path

	return 0
}

directory_check /usr/slog
directory_check /var/dlog
directory_check /var/log/hisi_logs
directory_check /var/log/hdcd

hdc_cdev_check

echo "startup slogd"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$homepath/driver/lib64
su ${username} -s /bin/sh -c "nohup $toolspath/slogd &"

echo "startup sklogd"
nohup $toolspath/sklogd &
sleep 0.1

echo "startup IDE-daemon-host"
su ${username} -s /bin/sh -c "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$homepath/driver/lib64;nohup $toolspath/IDE-daemon-host &"
sleep 0.1

echo "startup hdcd"
su ${username} -s /bin/sh -c "nohup $toolspath/hdcd >/dev/null 2>&1 &"
sleep 0.1

echo "atlas200 init finish"

exit 0
