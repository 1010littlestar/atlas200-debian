#!/bin/bash


usage() 
{
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "+  usage : ./mkdeb.sh <sdk_dir> [out_dir]                                                               +"
	echo "+  sdk_dir : A200-300-EP-SDK-V1.4.0 directory path                                                         +"
	echo "+  out_dir : [option] out path, if target_dir is null, set './out' as default                  +"
	echo "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
}

if [ ! -d $1 ]; then
    echo $1
    usage
fi

CUR_DIR=`pwd`
SDK_DIR="$1"
OUT_DIR="${CUR_DIR}/out"

des_dir=${OUT_DIR}/usr/local/HiAI
src_dir=${SDK_DIR}/lib


# lib/device
device_load0="Image davinci_mini.image"
device_load1="filesystem-le.cpio.gz davinci_mini.cpio.gz"
device_load2="dt.img davinci_mini_dt.img"
device_load3="HI1910_FPGA_DDR.fd davinci_mini.fd"
device_load4="tee.bin davinci_mini_tee.bin"
device_load5="lpm3.img davinci_mini_lpm3.img"

driver_libs_weakcheck=""

# lib/host
driver_libs="libdrvdevdrv.so libdrvdsmi_host.so libdrvhdc_host.so"
toolkit_libs="libslog.so libprofilerserver.so libprofilerclient.so"
toolkit_libs_weakcheck=""
runtime_libs="libc_sec.so libmatrix.so libmemory.so libprotobuf.so.15 libcrypto.so.1.1 libssl.so.1.1 libmmpa.so"
driver_bin="hdcd"
toolkit_bin="IDE-daemon-host IDE-daemon-client slogd sklogd slog.conf ide_daemon.cfg
            ide_daemon_cacert.pem  ide_daemon_client_cert.pem ide_daemon_client_key.pem ide_daemon_server_cert.pem 
            ide_daemon_server_key.pem ide_cmd.sh"
runtime_bin=""


# lib/device
firmware_bin="xloader.bin nve.bin Image lpm3.img HI1910_FPGA_DDR.fd tee.bin dt.img"
# lib/host
firmware_tools="upgrade-tool upgrade.cfg"

driver_boot="driver/boot/device_boot_pcie.sh driver/boot/davinci_boot_pcie_3559.sh"
driver_cfg="driver/config/project_user_config"

runtime_libs_weakcheck="libsafecity_ivs.so"

all_libs="$driver_libs $toolkit_libs $runtime_libs"
all_bins="$driver_bin $toolkit_bin $runtime_bin"
libs_weakcheck="$driver_libs_weakcheck $toolkit_libs_weakcheck $runtime_libs_weakcheck"

log() {
	cur_date=`date +"%Y-%m-%d %H:%M:%S"`
        echo "$cur_date "$1
}

param_check() {
	if [ $# -eq 1 ];then
        SDK_DIR="$1"
	elif [ $# -eq 2 ];then
        SDK_DIR="$1"
        OUT_DIR="$2"
	else
		usage
		return 1
	fi

    des_dir=${OUT_DIR}/usr/local/HiAI
    src_dir=${SDK_DIR}/lib

    if [ ! -d  ${src_dir} ]; then
        log "Can't find ${src_dir}"
        return 1
    fi
    rm -rf ${OUT_DIR}
    mkdir -v ${OUT_DIR}

	return 0
}

install_debian_files() {
    debian_dir=${CUR_DIR}/DEBIAN
    if [ ! -d ${debian_dir} ]; then
        echo "Can't find DEBIAN files, please check current path!"
        return 1
    fi 
    cp -a ${debian_dir} ${OUT_DIR}/
    log "copy DEBIAN finished"

    return 0
}

# 增加systemd 服务文件#
install_systemd_files() {
    mkdir -p ${OUT_DIR}/lib/systemd/system
    cp atlas200.service ${OUT_DIR}/lib/systemd/system/
    mkdir -p ${OUT_DIR}/usr/local/bin
    cp atlas200.sh ${OUT_DIR}/usr/local/bin/

    return 0
}

install_driver_ko() {
	mkdir -p $des_dir/driver/host
	if [ $? -ne 0 ];then
		log "mkdir -p $des_dir/driver/host failed"
		return 1
	fi

	cp $src_dir/host/*.ko $des_dir/driver/host/
	if [ $? -ne 0 ];then
		log "cp *.ko failed"
		return 1
	fi

	log "install kernel drivers success"
	return 0
}

install_libs() {
	# 与device_boot_pcie.sh脚本保存一致，后续改成$des_dir/lib64
	lib_dir=$des_dir/driver/lib64
	mkdir -p $lib_dir
	if [ $? -ne 0 ];then
		log "mkdir -p $lib_dir failed"
		return 1
	fi

	for lib in $all_libs;
	do
		tmplib=$src_dir/host/$lib
		if [ ! -f $tmplib ];then
			log "file $tmplib not existed, install failed"
			return 1
		fi

		cp $tmplib $lib_dir
		if [ $? -ne 0 ];then
			log "cp $tmplib $lib_dir failed"
			return 1
		fi
	done

	for lib in $libs_weakcheck;
	do
		tmplib=$src_dir/host/$lib
		if [ -f $tmplib ];then
			cp $tmplib $lib_dir
			if [ $? -ne 0 ];then
				log "cp $tmplib $lib_dir failed"
				return 1
			fi
		fi
	done

	log "install libs success"
	return 0
}

install_bins() {
	# 与device_boot_pcie.sh脚本保存一致，后续改成$des_dir/tools
	bin_dir=$des_dir/driver/tools
	mkdir -p $bin_dir
	if [ $? -ne 0 ];then
		log "mkdir -p $bin_dir failed"
		return 1
	fi

	for bin in $all_bins;
	do
		tmpbin=$src_dir/host/$bin
		if [ ! -f $tmpbin ];then
			log "file $tmpbin not existed, install failed"
			return 1
		fi

		cp $tmpbin $bin_dir
		if [ $? -ne 0 ];then
			log "cp $tmpbin $bin_dir failed"
			return 1
		fi
	done

    mkdir -p ${OUT_DIR}/etc/
    cp ${bin_dir}/slog.conf ${OUT_DIR}/etc/
    log "copy slog.conf"

	log "install bins success"
	return 0
}

install_boot() {
	boot_dir=$des_dir/driver/boot
	mkdir -p $boot_dir
	if [ $? -ne 0 ];then
		log "mkdir -p $boot_dir failed"
		return 1
	fi

	for file in $driver_boot;
	do
		tmpfile=$src_dir/host/$file
		if [ ! -f $tmpfile ];then
			log "file $tmpfile not existed, install failed"
			return 1
		fi

		cp $tmpfile $boot_dir
		if [ $? -ne 0 ];then
			log "cp $tmpfile $boot_dir failed"
			return 1
		fi
	done

	for file in $driver_cfg;
	do
	    tmpfile=$src_dir/host/$file
		if [ ! -f $tmpfile ];then
			log "file $tmpfile not existed, install failed"
			return 1
	    fi

        if [ ! -d $des_dir/driver/config/ ];then
            mkdir $des_dir/driver/config/
        fi

		cp $tmpfile $des_dir/driver/config/
		if [ $? -ne 0 ];then
			log "cp $tmpfile $des_dir/driver/config/ failed"
			return 1
		fi
	done

	log "install host boot success"
	return 0
}

load_file_cp_rename() {
	load_dir=$des_dir/driver/device

	if [ ! -f $src_dir/device/$1 ];then
		log "$src_dir/device/$1 missing, failed"
		return 1
	fi

	cp $src_dir/device/$1 $load_dir/$2
	if [ $? -ne 0 ];then
		log "cp $src_dir/device/$1 $load_dir/$2 failed"
		return 1
	fi

	return 0
}

install_load_file() {
	load_dir=$des_dir/driver/device
	mkdir -p $load_dir
	if [ $? -ne 0 ];then
		log "mkdir -p $load_dir failed"
		return 1
	fi

	ret=0
	load_file_cp_rename $device_load0
	ret=`expr $ret + $?`
	load_file_cp_rename $device_load1
	ret=`expr $ret + $?`
	load_file_cp_rename $device_load2
	ret=`expr $ret + $?`
	load_file_cp_rename $device_load3
	ret=`expr $ret + $?`
	load_file_cp_rename $device_load4
	ret=`expr $ret + $?`
	load_file_cp_rename $device_load5
	ret=`expr $ret + $?`

	return $ret
}

install_firmware() {
	firmware_dir=$des_dir/firmware
	mkdir -p $firmware_dir
	if [ $? -ne 0 ];then
		log "mkdir -p $firmware_dir failed"
		return 1
	fi

	for file in $firmware_bin;
	do
		tmpfile=$src_dir/device/$file
		if [ ! -f $tmpfile ];then
			log "file $tmpfile not existed, install failed"
			return 1
		fi

		cp $tmpfile $firmware_dir
		if [ $? -ne 0 ];then
			log "cp $tmpfile $firmware_dir failed"
			return 1
		fi
	done

	for file in $firmware_tools;
	do
		tmpfile=$src_dir/host/$file
		if [ ! -f $tmpfile ];then
			log "file $tmpfile not existed, install failed"
			return 1
		fi

		cp $tmpfile $firmware_dir
		if [ $? -ne 0 ];then
			log "cp $tmpfile $firmware_dir failed"
			return 1
		fi
	done

	cp ${SDK_DIR}/scripts/install/firmware_upgrade.sh $firmware_dir
	if [ $? -ne 0 ];then
		log "cp firmware_upgrade.sh $firmware_dir failed"
		return 1
	fi

	log "install firmware success"
	return 0
}

install_ide_daemon() {
    toolspath=${des_dir}/driver/tools
    ide_daemon_path=${OUT_DIR}/home/HwHiAiUser/ide_daemon
    if [ ! -d $ide_daemon_path ];then
        mkdir -p $ide_daemon_path
    fi
    chmod 700 $ide_daemon_path
    cp $toolspath/ide_daemon.cfg $ide_daemon_path
    cp $toolspath/ide_daemon_cacert.pem $ide_daemon_path
    cp $toolspath/ide_daemon_client_cert.pem $ide_daemon_path
    cp $toolspath/ide_daemon_client_key.pem $ide_daemon_path
    cp $toolspath/ide_daemon_server_cert.pem $ide_daemon_path
    cp $toolspath/ide_daemon_server_key.pem $ide_daemon_path

    mkdir -p ${OUT_DIR}/usr/bin
    cp $toolspath/ide_cmd.sh ${OUT_DIR}/usr/bin/

    return 0
}

install_cfgs() {
    if [ ! -d ${OUT_DIR}/lib ];then
        mkdir -p ${OUT_DIR}/lib
    fi
    echo DAVINCI_HOME_PATH=$homepath > ${OUT_DIR}/lib/davinci.conf
    return 0
}

param_check $*
if [ x"1" == x"$?" ]; then
    exit 1;
fi
install_debian_files
if [ x"1" == x"$?" ]; then
    exit 1;
fi
install_systemd_files
if [ x"1" == x"$?" ]; then
    exit 1;
fi
install_driver_ko
if [ x"1" == x"$?" ]; then
    exit 1;
fi
install_libs
if [ x"1" == x"$?" ]; then
    exit 1;
fi
install_bins
if [ x"1" == x"$?" ]; then
    exit 1;
fi
install_boot
if [ x"1" == x"$?" ]; then
    exit 1;
fi
install_load_file
if [ x"1" == x"$?" ]; then
    exit 1;
fi
install_firmware
if [ x"1" == x"$?" ]; then
    exit 1;
fi
install_ide_daemon
if [ x"1" == x"$?" ]; then
    exit 1;
fi

install_cfgs
if [ x"1" == x"$?" ]; then
    exit 1;
fi

dpkg-deb -b ${OUT_DIR} atlas200.deb

exit 0
