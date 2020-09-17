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

insmod $kopath/drv_seclib_host.ko
insmod $kopath/drv_pcie_host.ko type="3559"
insmod $kopath/drv_devmng_host.ko
insmod $kopath/drv_pcie_hdc_host.ko
insmod $kopath/drv_pcie_vnic_host.ko

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

if [ ! -d /var/dlog ] ; then
    mkdir -pv /var/dlog
fi
chmod -f 750 /var/dlog

if [ ! -d /var/log/hisi_logs ] ; then
    mkdir -pv /var/log/hisi_logs
fi
chmod -f 750 /var/log/hisi_logs

if [ ! -d /var/log/hdcd ] ; then
    mkdir -pv /var/log/hdcd
fi
chmod -f 750 /var/log/hdcd


export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$homepath/driver/lib64
su ${username} -s /bin/sh -c "nohup $toolspath/slogd &"
nohup $toolspath/sklogd &
sleep 0.1
su ${username} -s /bin/sh -c "export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$homepath/driver/lib64;nohup $toolspath/IDE-daemon-host &"
sleep 0.1
su ${username} -s /bin/sh -c "nohup $toolspath/hdcd >/dev/null 2>&1 &"
sleep 0.1

echo "startup hdcd"
echo "davinci host init finish"

exit 0