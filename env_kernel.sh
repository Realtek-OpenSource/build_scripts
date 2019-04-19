#!/bin/bash
[ "$ENV_KERNEL_SOURCE" != "" ] && return
ENV_KERNEL_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
source $SCRIPTDIR/env_platform.sh
source $SCRIPTDIR/env_hdcp.sh
source $SCRIPTDIR/env_secure_func.sh
source $SCRIPTDIR/env_android.sh
source $SCRIPTDIR/env_vmx.sh
KERNELDIR=$TOPDIR/linux-kernel

config_get GERRIT_MANIFEST

GOLDEN_OBSOLETE_CONFIG=$PLATFORMDIR/system/configs/golden_obsolete_config
GOLDEN_IMG_DIR=$KERNELDIR/golden_img

LINUX_KERNEL_VERSION_LIST="kernel_4.1 kernel_4.4 kernel_4.9"
KERNEL_VERSION_EX=""
TARGET_CHIP_ARCH=""

export KERNEL_VERSION
export KERNEL_PATCHLEVEL

function kernel_version()
{
    if [ -e "${KERNELDIR}/Makefile" ]; then
        KERNEL_VERSION=$(grep -m1 -A0 "VERSION =" "${KERNELDIR}/Makefile")
        KERNEL_PATCHLEVEL=$(grep -m1 -A0 "PATCHLEVEL =" "${KERNELDIR}/Makefile")
        export KERNEL_VERSION
        export KERNEL_PATCHLEVEL
    fi
}

function kernel_version_is_4p14()
{
    kernel_version > /dev/null
    if [ "$KERNEL_VERSION" == "VERSION = 4" ] && [ "$KERNEL_PATCHLEVEL" == "PATCHLEVEL = 14"  ]; then
        return 0
    else
        return 1
    fi
}


function kernel_version_is_3p10()
{
    kernel_version > /dev/null
    if [ "$KERNEL_VERSION" == "VERSION = 3" ] && [ "$KERNEL_PATCHLEVEL" == "PATCHLEVEL = 10"  ]; then
        return 0
    else
        return 1
    fi
}

function kernel_version_is_4p9()
{
    kernel_version > /dev/null
    if [ "$KERNEL_VERSION" == "VERSION = 4" ] && [ "$KERNEL_PATCHLEVEL" == "PATCHLEVEL = 9"  ]; then
        return 0
    else
        return 1
    fi
}

function kernel_version_is_4p4()
{
    kernel_version > /dev/null
    if [ "$KERNEL_VERSION" == "VERSION = 4" ] && [ "$KERNEL_PATCHLEVEL" == "PATCHLEVEL = 4"  ]; then
        return 0
    else
        return 1
    fi
}

function kernel_version_is_4p1()
{
    kernel_version > /dev/null
    if [ "$KERNEL_VERSION" == "VERSION = 4" ] && [ "$KERNEL_PATCHLEVEL" == "PATCHLEVEL = 1"  ]; then
        return 0
    else
        return 1
    fi
}

function kernel_export_version_get()
{
    version=
    if [ -d "$KERNELDIR" ]; then
        pushd $KERNELDIR > /dev/null
            version=`git log --pretty=format:'%h' -n 1`
        popd > /dev/null
    else
        version="N/A"
    fi

    [ "$1" != "" ] && export $1=${version} || echo ${version}
    return 0
}

function kernel_dir_get()
{
    item=$1
    dir=$KERNELDIR
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function kernel_boot_dir_get()
{
    kernel_prepare_parameters > /dev/null
    dir=`kernel_dir_get`/arch/$ARCH/boot
    [ "$1" != "" ] && export $1=${dir} || echo ${dir}
    return 0
}

function kernel_device_tree_dir_get()
{
    kernel_version > /dev/null
    kernel_prepare_parameters > /dev/null
    if kernel_version_is_4p4 ; then
        case "$KERNEL_TARGET_CHIP" in
            kylin)
                dir=`kernel_boot_dir_get`/dts/$KERNEL_TARGET_VENDOR/RTD129x
                ;;
            hercules)
                dir=`kernel_boot_dir_get`/dts/$KERNEL_TARGET_VENDOR/RTD139x
                ;;
            *)
                exit 1
                ;;
        esac
    elif kernel_version_is_4p9 ; then
        case "$KERNEL_TARGET_CHIP" in
            kylin)
                dir=`kernel_boot_dir_get`/dts/$KERNEL_TARGET_VENDOR/rtd129x
                ;;
            hercules)
                dir=`kernel_boot_dir_get`/dts/$KERNEL_TARGET_VENDOR/rtd139x
                ;;
            thor)
                dir=`kernel_boot_dir_get`/dts/$KERNEL_TARGET_VENDOR/rtd16xx
                ;;
            hank)
                dir=`kernel_boot_dir_get`/dts/$KERNEL_TARGET_VENDOR/rtd13xx
                ;;
            *)
                exit 1
                ;;
        esac
    elif kernel_version_is_4p14 ; then
        case "$KERNEL_TARGET_CHIP" in
            hercules)
                dir=`kernel_boot_dir_get`/dts/$KERNEL_TARGET_VENDOR/rtd139x
                ;;
            thor)
                dir=`kernel_boot_dir_get`/dts/$KERNEL_TARGET_VENDOR/rtd16xx
                ;;
            hank)
                dir=`kernel_boot_dir_get`/dts/$KERNEL_TARGET_VENDOR/rtd13xx
                ;;
            *)
                exit 1
                ;;
        esac
    else
        dir=`kernel_boot_dir_get`/dts/$KERNEL_TARGET_VENDOR
    fi

    [ "$1" != "" ] && export $1=${dir} || echo ${dir}
    return 0
}

function kernel_merge_config()
{
    local config_file=$1
    local merge_file=$2

    if [ ! -e "$merge_file" ] ; then
        echo "*** WARNING! *** $merge_file : file not found! (kernel_merge_config $@)"
        return 1
    fi
    if [ ! -e "$config_file" ] ; then
        echo "*** WARNING! *** $config_file : file not found! (kernel_merge_config $@)"
        return 2
    fi

    local OLD_IFS=$IFS
    IFS=$'\n'

    local check_list=`cat $merge_file |sed 's/^\ *$//g' |sed '/^$/d'`
    for item_line in $check_list
    do
        local need_disable=`echo $item_line|grep "^\ *#\|^#" | wc -l`
        local need_enable=`echo $item_line|grep "^\ *CONFIG_\|^CONFIG_" |wc -l`

        if [ "$need_disable" != "0" ] && [ "$need_enable" != "0" ]; then
            echo "ERROR! ($@) $item_line at $merge_file"
            continue
        fi

        if [ "$need_disable" != "0" ]; then
            local item=`echo $item_line |sed 's/\ *#/#/g'|sed 's/^#//g'|sed 's/^\ *//g'|sed 's/\ .*//g'`
            sed -ie 's|'"^.*${item}[[:blank:]=].*$"'|'"${item_line}"'|g' ${config_file}
        fi

        if [ "$need_enable" != "0" ]; then
            local item=`echo $item_line |sed 's/\ *CONFIG_/CONFIG_/g'|sed 's/=.*$//g' |sed 's/\ *//g'`
            sed -ie 's|'"^.*${item}[[:blank:]=].*$"'|'"${item_line}"'|g' ${config_file}
        fi
    done

    IFS=$OLD_IFS
    return 0
}

function kernel_image_get()
{
    kernel_prepare_parameters > /dev/null
    file=`kernel_boot_dir_get`/${KERNEL_IMAGE}
    [ "$1" != "" ] && export $1=${file} || echo ${file}
    return 0
}

function kernel_golden_dir_get()
{
    item=$1
    dir=$GOLDEN_IMG_DIR
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}


function kernel_init()
{
    [ ! -d "$KERNELDIR" ] && mkdir $KERNELDIR
    pushd $KERNELDIR > /dev/null
    repo init -u $GERRIT_MANIFEST -b master -m linux-kernel.xml $REPO_PARA
    popd > /dev/null
    return 0
}

function kernel_sync()
{
    ERR=0
    [ ! -d "$KERNELDIR" ] && return 1
    pushd $KERNELDIR > /dev/null
        repo sync --force-sync
        ERR=$?
        #git status -s | grep -v "^??"
    popd > /dev/null
    return $ERR;
}


function kernel_checkout()
{
    ERR=0
    platform_checkout || return 1
    if [ ! -e "$KERNELDIR/.repo_ready" ]; then
        kernel_init && kernel_sync && (> ${KERNELDIR}/.repo_ready) || ERR=1
    fi
    return $ERR;
}

function kernel_config()
{
    hdcp_config

    config_get_bool SHRINK_GOLDEN_IMG true

    secure_func_config

    TARGET_CHIP_ARCH_LIST="arm32 arm64"

    config_get_menu TARGET_CHIP_ARCH TARGET_CHIP_ARCH_LIST arm64

    if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
        KERNEL_TARGET_CHIP_LIST="kylin hercules thor hank"
    elif [ "$TARGET_CHIP_ARCH" = "arm32" ]; then
        KERNEL_TARGET_CHIP_LIST="phoenix kylin hercules thor hank"
    fi

    if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
        config_get_menu KERNEL_TARGET_CHIP KERNEL_TARGET_CHIP_LIST kylin
    else
        config_get_menu KERNEL_TARGET_CHIP KERNEL_TARGET_CHIP_LIST phoenix
    fi

    vmx_config

    config_get KERNEL_DEF_CONFIG && return 0

    unset KERNEL_DEF_CONFIG

    if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
        KERNEL_TARGET_CHIP_LIST="kylin hercules thor hank"
        if [ "$KERNEL_TARGET_CHIP" = "kylin" ]; then
            LINUX_KERNEL_VERSION_LIST="kernel_4.1 kernel_4.4 kernel_4.9"
            DEFAULT_KERNEL="kernel_4.1"
        else
            LINUX_KERNEL_VERSION_LIST="kernel_4.9"
            DEFAULT_KERNEL="kernel_4.9"
        fi
        config_get_menu LINUX_KERNEL_VERSION LINUX_KERNEL_VERSION_LIST $DEFAULT_KERNEL
    elif [ "$TARGET_CHIP_ARCH" = "arm32" ]; then
        KERNEL_TARGET_CHIP_LIST="phoenix kylin hercules thor hank"
        if [ "$KERNEL_TARGET_CHIP" = "phoenix" ]; then
            LINUX_KERNEL_VERSION_LIST="kernel_3.10 kernel_4.9"
            DEFAULT_KERNEL="kernel_3.10"
        else
            LINUX_KERNEL_VERSION_LIST="kernel_4.9 kernel_4.14"
            DEFAULT_KERNEL="kernel_4.9"
        fi
        config_get_menu LINUX_KERNEL_VERSION LINUX_KERNEL_VERSION_LIST $DEFAULT_KERNEL
    fi

    if [ -d "$PLATFORMDIR/system/configs" ]; then
        pushd $PLATFORMDIR/system/configs > /dev/null
            if [ "$KERNEL_TARGET_CHIP" = "kylin" ]; then
                KERNEL_DEF_CONFIG_LIST=`ls rtk129x_*_defconfig`
                DEFAULT_KERNEL_CONFIG=rtk129x_android_emmc_defconfig
                if [ "$LINUX_KERNEL_VERSION" = "kernel_4.1" ]; then
                    pushd $PLATFORMDIR/system/configs > /dev/null
                        KERNEL_DEF_CONFIG_LIST=`ls rtk129x_*_defconfig`
                        DEFAULT_KERNEL_CONFIG=rtk129x_android_emmc_defconfig
                    popd > /dev/null
                elif [ "$LINUX_KERNEL_VERSION" = "kernel_4.4" ]; then
                    pushd $PLATFORMDIR/system/configs/kernel4.4 > /dev/null
                        KERNEL_DEF_CONFIG_LIST=`ls rtd129x_*_defconfig`
                        DEFAULT_KERNEL_CONFIG=rtd129x_android_emmc_defconfig
                    popd > /dev/null
                elif [ "$LINUX_KERNEL_VERSION" = "kernel_4.9" ]; then
                    pushd $PLATFORMDIR/system/configs/kernel4.9 > /dev/null
                        KERNEL_DEF_CONFIG_LIST=`ls rtd129x_*_defconfig`
                        DEFAULT_KERNEL_CONFIG=rtd129x_android_emmc_defconfig
                    popd > /dev/null
                else
                    KERNEL_DEF_CONFIG_LIST=`ls rtk129x_*_defconfig`
                    DEFAULT_KERNEL_CONFIG=rtk129x_android_emmc_defconfig
                fi
            elif [ "$KERNEL_TARGET_CHIP" = "hercules" ]; then
                if [ "$LINUX_KERNEL_VERSION" = "kernel_4.4" ]; then
                    pushd $PLATFORMDIR/system/configs/kernel4.4 > /dev/null
                        KERNEL_DEF_CONFIG_LIST=`ls rtd139x_*_defconfig`
                        DEFAULT_KERNEL_CONFIG=rtd139x_android_emmc_defconfig
                    popd > /dev/null
                elif [ "$LINUX_KERNEL_VERSION" = "kernel_4.9" ]; then
                    if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                        pushd $PLATFORMDIR/system/configs/kernel4.9 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd139x_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd139x_android_emmc_defconfig
                        popd > /dev/null
                    else
                        pushd $PLATFORMDIR/system/configs/kernel4.9 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd139x_aarch32_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd139x_aarch32_android_emmc_defconfig
                        popd > /dev/null
                    fi
		elif [ "$LINUX_KERNEL_VERSION" = "kernel_4.14" ]; then
                    if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                        pushd $PLATFORMDIR/system/configs/kernel4.14 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd139x_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd139x_android_emmc_defconfig
                        popd > /dev/null
                    else
                        pushd $PLATFORMDIR/system/configs/kernel4.14 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd139x_aarch32_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd139x_aarch32_android_emmc_defconfig
                        popd > /dev/null
                    fi
                fi
            elif [ "$KERNEL_TARGET_CHIP" = "thor" ]; then
                if [ "$LINUX_KERNEL_VERSION" = "kernel_4.9" ]; then
                    if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                        pushd $PLATFORMDIR/system/configs/kernel4.9 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd16xx_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd16xx_android-8.0_emmc_defconfig
                        popd > /dev/null
                    else
                        pushd $PLATFORMDIR/system/configs/kernel4.9 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd16xx_aarch32_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd16xx_aarch32_android_emmc_defconfig
                        popd > /dev/null
                    fi
		elif [ "$LINUX_KERNEL_VERSION" = "kernel_4.14" ]; then
		    if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                        pushd $PLATFORMDIR/system/configs/kernel4.14 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd16xx_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd16xx_android-8.0_emmc_defconfig
                        popd > /dev/null
                    else
                        pushd $PLATFORMDIR/system/configs/kernel4.14 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd16xx_aarch32_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd16xx_aarch32_android_emmc_defconfig
                        popd > /dev/null
                    fi
                fi
            elif [ "$KERNEL_TARGET_CHIP" = "hank" ]; then
                if [ "$LINUX_KERNEL_VERSION" = "kernel_4.9" ]; then
                    if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                        pushd $PLATFORMDIR/system/configs/kernel4.9 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd13xx_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd13xx_android-8.0_emmc_defconfig
                        popd > /dev/null
                    else
                        pushd $PLATFORMDIR/system/configs/kernel4.9 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd13xx_aarch32_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd13xx_aarch32_android_emmc_defconfig
                        popd > /dev/null
                    fi
		elif [ "$LINUX_KERNEL_VERSION" = "kernel_4.14" ]; then
                    if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                        pushd $PLATFORMDIR/system/configs/kernel4.14 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd13xx_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd16xx_android-8.0_emmc_defconfig
                        popd > /dev/null
                    else
                        pushd $PLATFORMDIR/system/configs/kernel4.14 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd13xx_aarch32_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd16xx_aarch32_android_emmc_defconfig
                        popd > /dev/null
                    fi
                fi
            elif [ "$KERNEL_TARGET_CHIP" = "phoenix" ]; then
                if [ "$LINUX_KERNEL_VERSION" = "kernel_4.9" ]; then
                    pushd $PLATFORMDIR/system/configs/kernel4.9 > /dev/null
                        KERNEL_DEF_CONFIG_LIST=`ls rtd119x_*_defconfig`
                        DEFAULT_KERNEL_CONFIG=rtd119x_android_emmc_defconfig
                    popd > /dev/null
                else
                    KERNEL_DEF_CONFIG_LIST=`ls rtk119x_*_defconfig`
                    DEFAULT_KERNEL_CONFIG=rtk119x_android_emmc_defconfig
                fi
            else
                KERNEL_DEF_CONFIG_LIST=
            fi
        popd > /dev/null
    else
        [ -d build-config ] && rm -rf build-config

        mkdir build-config
        pushd build-config > /dev/null
            build_cmd repo init -u $GERRIT_MANIFEST -b master -m linux-kernel.xml $REPO_PARA
            build_cmd repo sync --force-sync
            pushd kernel-configs > /dev/null
                if [ "$KERNEL_TARGET_CHIP" = "kylin" ]; then
                    if [ "$LINUX_KERNEL_VERSION" = "kernel_4.1" ]; then
                        KERNEL_DEF_CONFIG_LIST=`ls rtk129x_*_defconfig`
                        DEFAULT_KERNEL_CONFIG=rtk129x_android_emmc_defconfig
                    elif [ "$LINUX_KERNEL_VERSION" = "kernel_4.4" ]; then
                        pushd kernel4.4 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd129x_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd129x_android_emmc_defconfig
                        popd > /dev/null
                    elif [ "$LINUX_KERNEL_VERSION" = "kernel_4.9" ]; then
                        pushd kernel4.9 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd129x_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd129x_android_emmc_defconfig
                        popd > /dev/null
                    fi
                elif [ "$KERNEL_TARGET_CHIP" = "hercules" ]; then
                    if [ "$LINUX_KERNEL_VERSION" = "kernel_4.4" ]; then
                        pushd kernel4.4 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd139x_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd139x_android_emmc_defconfig
                        popd > /dev/null
                    elif [ "$LINUX_KERNEL_VERSION" = "kernel_4.9" ]; then
                        if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                            pushd kernel4.9 > /dev/null
                                KERNEL_DEF_CONFIG_LIST=`ls rtd139x_*_defconfig`
                                DEFAULT_KERNEL_CONFIG=rtd139x_android_emmc_defconfig
                            popd > /dev/null
                        else
                            pushd kernel4.9 > /dev/null
                                KERNEL_DEF_CONFIG_LIST=`ls rtd139x_aarch32_*_defconfig`
                                DEFAULT_KERNEL_CONFIG=rtd139x_aarch32_android_emmc_defconfig
                            popd > /dev/null
                        fi
		    elif [ "$LINUX_KERNEL_VERSION" = "kernel_4.14" ]; then
                        if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                            pushd kernel4.14 > /dev/null
                                KERNEL_DEF_CONFIG_LIST=`ls rtd139x_*_defconfig`
                                DEFAULT_KERNEL_CONFIG=rtd139x_android_emmc_defconfig
                            popd > /dev/null
                        else
                            pushd kernel4.14 > /dev/null
                                KERNEL_DEF_CONFIG_LIST=`ls rtd139x_aarch32_*_defconfig`
                                DEFAULT_KERNEL_CONFIG=rtd139x_aarch32_android_emmc_defconfig
                            popd > /dev/null
                        fi
                    fi
                elif [ "$KERNEL_TARGET_CHIP" = "thor" ]; then
                    if [ "$LINUX_KERNEL_VERSION" = "kernel_4.9" ]; then
                        if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                            pushd kernel4.9 > /dev/null
                                KERNEL_DEF_CONFIG_LIST=`ls rtd16xx_*_defconfig`
                                DEFAULT_KERNEL_CONFIG=rtd16xx_android-8.0_emmc_defconfig
                            popd > /dev/null
                        else
                            pushd kernel4.9 > /dev/null
                                KERNEL_DEF_CONFIG_LIST=`ls rtd16xx_aarch32_*_defconfig`
                                DEFAULT_KERNEL_CONFIG=rtd16xx_aarch32_android_emmc_defconfig
                            popd > /dev/null
                        fi
		    elif [ "$LINUX_KERNEL_VERSION" = "kernel_4.14" ]; then
                        if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                            pushd kernel4.14 > /dev/null
                                KERNEL_DEF_CONFIG_LIST=`ls rtd16xx_*_defconfig`
                                DEFAULT_KERNEL_CONFIG=rtd139x_android_emmc_defconfig
                            popd > /dev/null
                        else
                            pushd kernel4.14 > /dev/null
                                KERNEL_DEF_CONFIG_LIST=`ls rtd16xx_aarch32_*_defconfig`
                                DEFAULT_KERNEL_CONFIG=rtd139x_aarch32_android_emmc_defconfig
                            popd > /dev/null
                        fi
                    fi
                elif [ "$KERNEL_TARGET_CHIP" = "hank" ]; then
                    if [ "$LINUX_KERNEL_VERSION" = "kernel_4.9" ]; then
                        if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                            pushd kernel4.9 > /dev/null
                                KERNEL_DEF_CONFIG_LIST=`ls rtd13xx_*_defconfig`
                                DEFAULT_KERNEL_CONFIG=rtd13xx_android-8.0_emmc_defconfig
                            popd > /dev/null
                        else
                            pushd kernel4.9 > /dev/null
                                KERNEL_DEF_CONFIG_LIST=`ls rtd13xx_aarch32_*_defconfig`
                                DEFAULT_KERNEL_CONFIG=rtd13xx_aarch32_android_emmc_defconfig
                            popd > /dev/null
                        fi
		    elif [ "$LINUX_KERNEL_VERSION" = "kernel_4.14" ]; then
                        if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                            pushd kernel4.14 > /dev/null
                                KERNEL_DEF_CONFIG_LIST=`ls rtd13xx_*_defconfig`
                                DEFAULT_KERNEL_CONFIG=rtd139x_android_emmc_defconfig
                            popd > /dev/null
                        else
                            pushd kernel4.14 > /dev/null
                                KERNEL_DEF_CONFIG_LIST=`ls rtd13xx_aarch32_*_defconfig`
                                DEFAULT_KERNEL_CONFIG=rtd139x_aarch32_android_emmc_defconfig
                            popd > /dev/null
                        fi
                    fi
                elif [ "$KERNEL_TARGET_CHIP" = "phoenix" ]; then
                    if [ "$LINUX_KERNEL_VERSION" = "kernel_4.9" ]; then
                        pushd kernel4.9 > /dev/null
                            KERNEL_DEF_CONFIG_LIST=`ls rtd119x_*_defconfig`
                            DEFAULT_KERNEL_CONFIG=rtd119x_android_emmc_defconfig
                        popd > /dev/null
                    else
                        KERNEL_DEF_CONFIG_LIST=`ls rtk119x_*_defconfig`
                        DEFAULT_KERNEL_CONFIG=rtk119x_android_emmc_defconfig
                    fi
                else
                    KERNEL_DEF_CONFIG_LIST=
                fi
            popd > /dev/null
        popd > /dev/null

        [ -d build-config ] && rm -rf build-config
    fi

    config_get_menu KERNEL_DEF_CONFIG KERNEL_DEF_CONFIG_LIST $DEFAULT_KERNEL_CONFIG

    config_get KERNEL_DEF_CONFIG || return 1
}

function kernel_config_check_android()
{
    pushd $KERNELDIR > /dev/null
    ANDROID_VERSION=`get_android_major_version`
    if [ $ANDROID_VERSION -le 8 ]; then
        echo old android, choose binder ipc mode by config
        if android_type_is_64; then
            kernel_merge_config .config android/configs/android-64bit.cfg

            # legacy : need to remove in the future
            [ "$?" != "0" ] && sed -i 's/CONFIG_ANDROID_BINDER_IPC_32BIT=y/# CONFIG_ANDROID_BINDER_IPC_32BIT is not set/' .config
        else
            kernel_merge_config .config android/configs/android-32bit.cfg

            # legacy : need to remove in the future
            [ "$?" != "0" ] && sed -i 's/# CONFIG_ANDROID_BINDER_IPC_32BIT is not set/CONFIG_ANDROID_BINDER_IPC_32BIT=y/' .config
        fi
    else
        # starting from android 9.0, always use 64-bit binder ipc
        echo new android, always sticks to 64-bit binder ipc
        kernel_merge_config .config android/configs/android-64bit.cfg

        # legacy : need to remove in the future
        [ "$?" != "0" ] && sed -i 's/CONFIG_ANDROID_BINDER_IPC_32BIT=y/# CONFIG_ANDROID_BINDER_IPC_32BIT is not set/' .config
    fi
    popd > /dev/null
    return 0
}

function kernel_config_check_tee()
{
    config_get DRM_OPTION
    pushd $KERNELDIR > /dev/null
    if [ "$BRANCH_QA_TARGET" = "CustBranch-QA160627" ] || [ "$BRANCH_QA_TARGET" = "CustBranch-QA160627-nuplayer-2016-11-17" ]; then
        if [ -e "$KERNELDIR/.config" ]; then
                sed -i 's/CONFIG_TEE_SUPPORT=y/CONFIG_TEE_SUPPORT=n/' .config
        fi
    fi
    
   echo "Enable TEE driver"
   sed -i 's/# CONFIG_OPTEE is not set/CONFIG_OPTEE=y/' .config
   sed -i 's/# CONFIG_TEE is not set/CONFIG_TEE=y/' .config
   #scripts/kconfig/merge_config.sh .config android/configs/tee-driver-enable.cfg	

    
    #if [ "$DRM_OPTION" != "off" ]; then
    #   if [ -e "$KERNELDIR/.config" ]; then
    #            echo "Enable TEE driver"
    #            sed -i 's/# CONFIG_OPTEE is not set/CONFIG_OPTEE=y/' .config
    #            sed -i 's/# CONFIG_TEE is not set/CONFIG_TEE=y/' .config
    #            #scripts/kconfig/merge_config.sh .config android/configs/tee-driver-enable.cfg
    #    fi
    #else
    #    if [ -e "$KERNELDIR/.config" ]; then
    #            echo "Disable TEE driver"
    #            sed -i 's/CONFIG_OPTEE=y/# CONFIG_OPTEE is not set/' .config
    #            sed -i 's/CONFIG_TEE=y/# CONFIG_TEE is not set/' .config
    #            #scripts/kconfig/merge_config.sh .config android/configs/tee-driver-disable.cfg
    #    fi
    #fi
    popd > /dev/null
    return 0
}

function kernel_config_check_vmx()
{
    config_get VMX_TYPE

    pushd $KERNELDIR > /dev/null
        if vmx_is_enable_boot_flow; then
            if [ "${VMX_TYPE}" == "ultra" ]; then
                if vmx_is_enable_boot_flow ; then
                    kernel_merge_config .config android/configs/vmx-ultra-boot.cfg

                    # legacy : need to remove in the future
                    [ "$?" != "0" ] && sed -i 's/# CONFIG_RTK_VMX_ULTRA is not set/CONFIG_RTK_VMX_ULTRA=y' .config
                fi
            else
                vmx_is_enable_boot_flow && kernel_merge_config .config android/configs/vmx-boot.cfg
            fi
            sed -i -- 's/rtd-1295.dtsi/rtd-1295-vmx.dtsi/g' `image_rescue_dts_get`
        else
            sed -i -- 's/rtd-1295-vmx.dtsi/rtd-1295.dtsi/g' `image_rescue_dts_get`
	
	    kernel_merge_config .config android/configs/vmx-ultra-boot-disable.cfg
	    if vmx_config_is_enable; then
	        if drm_type_is_with_svp; then
	            kernel_merge_config .config android/configs/vmx-drm.cfg
	        else
		    kernel_merge_config .config android/configs/vmx-drm-disable.cfg
	        fi
	    else
		kernel_merge_config .config android/configs/vmx-drm-disable.cfg
	    fi
        fi
	
	if vmx_config_is_enable; then
	    if vmx_hardening_is_enable; then
	        kernel_merge_config .config android/configs/linux-hardening.cfg
	    fi
        fi	

    popd > /dev/null
    return 0
}

function kernel_config_check_hdcp()
{
    pushd $KERNELDIR > /dev/null
        if hdcp_is_enable; then
            hdcp_tx_1px_en && kernel_merge_config .config android/configs/hdcp-tx-1Px.cfg
            hdcp_tx_2p2_en && kernel_merge_config .config android/configs/hdcp-tx-2P2.cfg
            hdcp_rx_1px_en && kernel_merge_config .config android/configs/hdcp-rx-1Px.cfg
            hdcp_rx_2p2_en && kernel_merge_config .config android/configs/hdcp-rx-2P2.cfg
            if hdcp_tx_tee_en; then
                kernel_merge_config .config android/configs/hdcp-tx-TEE.cfg

                # legacy : need to remove in the future
                [ "$?" != "0" ] && sed -i 's/# CONFIG_RTK_HDCP_1x_TEE is not set/CONFIG_RTK_HDCP_1x_TEE=y' .config
            else
                kernel_merge_config .config android/configs/hdcp-tx-TEE-disable.cfg

                # legacy : need to remove in the future
                [ "$?" != "0" ] && sed -i 's/CONFIG_RTK_HDCP_1x_TEE=y/# CONFIG_RTK_HDCP_1x_TEE is not set/' .config
            fi
            if hdcp_rx_tee_en; then
                if hdcp_rx_1px_en ; then
                    kernel_merge_config .config android/configs/hdcp-rx-1Px-TEE.cfg

                    # legacy : need to remove in the future
                    [ "$?" != "0" ] && sed -i 's/# RTK_HDCPRX_1P4_TEE is not set/RTK_HDCPRX_1P4_TEE=y/' .config
                fi
            else
                kernel_merge_config .config android/configs/hdcp-rx-TEE-disable.cfg

                # legacy : need to remove in the future
                [ "$?" != "0" ] && sed -i 's/RTK_HDCPRX_1P4_TEE=y/# RTK_HDCPRX_1P4_TEE is not set/' .config
            fi
        else
            kernel_merge_config .config android/configs/hdcp-disable.cfg
        fi
    popd > /dev/null
    return 0
}

function kernel_config_check_dmverity()
{
    pushd $KERNELDIR > /dev/null
        #if secure_func_dmverity_is_enable; then
        #    hdcp_tx_tee_en && scripts/kconfig/merge_config.sh .config android/configs/dmverity.cfg
        #else
        #    scripts/kconfig/merge_config.sh .config android/configs/dmverity-disable.cfg
        #fi
    popd > /dev/null
    return 0
}

function kernel_config_check()
{
    if [ -e "$KERNELDIR/.config" ]; then
        if kernel_version_is_4p4 ; then
            diff -u $PLATFORMDIR/system/configs/kernel4.4/$KERNEL_DEF_CONFIG $KERNELDIR/.config
        elif kernel_version_is_4p9 ; then
            diff -u $PLATFORMDIR/system/configs/kernel4.9/$KERNEL_DEF_CONFIG $KERNELDIR/.config
        elif kernel_version_is_4p14 ; then
            diff -u $PLATFORMDIR/system/configs/kernel4.14/$KERNEL_DEF_CONFIG $KERNELDIR/.config
        else
            diff -u $PLATFORMDIR/system/configs/$KERNEL_DEF_CONFIG $KERNELDIR/.config
        fi
        if [ "$?" == "1" ]; then
            echo -e "\033[31m.config & $KERNEL_DEF_CONFIG differ, forget to update?\033[m"
        fi
    else
        if kernel_version_is_4p4 ; then
            cp -f $PLATFORMDIR/system/configs/kernel4.4/$KERNEL_DEF_CONFIG $KERNELDIR/.config || return 1
        elif kernel_version_is_4p9 ; then
            cp -f $PLATFORMDIR/system/configs/kernel4.9/$KERNEL_DEF_CONFIG $KERNELDIR/.config || return 1
        elif kernel_version_is_4p14 ; then
            cp -f $PLATFORMDIR/system/configs/kernel4.14/$KERNEL_DEF_CONFIG $KERNELDIR/.config || return 1
        else
            cp -f $PLATFORMDIR/system/configs/$KERNEL_DEF_CONFIG $KERNELDIR/.config || return 1
        fi
    fi

    pushd $KERNELDIR > /dev/null
        yes "" | make oldconfig || return $?
        #make olddefconfig || return $?
        #make alldefconfig || return $?
        #make silentoldconfig || return $?
    popd > /dev/null

    kernel_config_check_android
    kernel_config_check_tee
    kernel_config_check_hdcp
    kernel_config_check_vmx
    kernel_config_check_dmverity

    return 0
}

function kernel_dtboimg()
{
    ANDROID_VERSION=`get_android_major_version`
    if [ $ANDROID_VERSION -le 8 ]; then
        return 0
    fi

    if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
        ARCH_DIR=arm64
    elif [ "$TARGET_CHIP_ARCH" = "arm32" ]; then
        ARCH_DIR=arm
    fi

    if [ "`grep \"CONFIG_ARCH_RTD129x=y\" $KERNELDIR/.config`" != "" ]; then
        DTBO_DIR=$KERNELDIR/arch/$ARCH_DIR/boot/dts/realtek/rtd129x/dtbo
        DTBOCFG=${DTBO_DIR}/rtd-129x-dtboimg.cfg
    elif [ "`grep \"CONFIG_ARCH_RTD139x=y\" $KERNELDIR/.config`" != "" ]; then
        DTBO_DIR=$KERNELDIR/arch/$ARCH_DIR/boot/dts/realtek/rtd139x/dtbo
        DTBOCFG=${DTBO_DIR}/rtd-139x-dtboimg.cfg
    elif [ "`grep \"CONFIG_ARCH_RTD16xx=y\" $KERNELDIR/.config`" != "" ]; then
        DTBO_DIR=$KERNELDIR/arch/$ARCH_DIR/boot/dts/realtek/rtd16xx/dtbo
        DTBOCFG=${DTBO_DIR}/rtd-16xx-dtboimg.cfg
    fi

    pushd $DTBO_DIR > /dev/null
        DTC=$PLATFORMDIR/toolchain/dtb_overlay_tool/dtc
        MKDTIMG=$PLATFORMDIR/toolchain/dtb_overlay_tool/mkdtimg
        for d in *.dts; do
            DTBO_NAME=${d:0:-4}
            $DTC -W no-unit_address_vs_reg -@ -a 4 -O dtb -o ${DTBO_NAME}.dtbo $d 
        done
        $MKDTIMG cfg_create ${DTBOCFG:0:-12}.dtboimg ${DTBOCFG}
    popd > /dev/null

    return 0
}

function kernel_build()
{
    BUILD_PARAMETERS=$*
    pushd $KERNELDIR > /dev/null
        # Tell Build system using default .config when building normal kernel
        export KCONFIG_CONFIG=.config
        ANDROID_VERSION=`get_android_major_version`
        if [ $ANDROID_VERSION -le 8 ]; then
            echo "general dtc"
            make -j $MULTI -l $LOAD_AVERAGE $BUILD_PARAMETERS DTC_FLAGS="-p 8192"
        else
            echo "android dtc"
            make -j $MULTI -l $LOAD_AVERAGE $BUILD_PARAMETERS DTC_FLAGS="-p 8192 -@" DTC="$PLATFORMDIR/toolchain/dtb_overlay_tool/dtc"
        fi
        ERR=$?
    popd > /dev/null
    return $ERR
}

function kernel_golden_build()
{
    BUILD_PARAMETERS=$*
    config_get SHRINK_GOLDEN_IMG
    if [ "$SHRINK_GOLDEN_IMG" = "true" ]; then
        echo "Build Shrinked Golden Kernel..."

        pushd $KERNELDIR > /dev/null
            if [ -e "$GOLDEN_OBSOLETE_CONFIG" ]; then
                # Use .config_golden for golden-kernel so .config (normal-kernel) stays clean
                export KCONFIG_CONFIG=.config_golden
                #export KBUILD_OUTPUT=$GOLDEN_KERNELDIR
                cp .config .config_golden
                scripts/kconfig/merge_config.sh .config_golden $GOLDEN_OBSOLETE_CONFIG
                make -j $MULTI -l $LOAD_AVERAGE $BUILD_PARAMETERS DTC_FLAGS="-p 8192"
                if [ "$?" == "0" ]; then
                    export KCONFIG_CONFIG=.config #restore KCONFIG for normal build flow
                    test -d $GOLDEN_IMG_DIR || mkdir -p $GOLDEN_IMG_DIR
                    GOLDEN_KERNEL_IMG=`kernel_image_get`
                    GOLDEN_DTB_PATH=`kernel_device_tree_dir_get`
                    cp $GOLDEN_KERNEL_IMG $GOLDEN_IMG_DIR/
                    cp vmlinux $GOLDEN_IMG_DIR/
                    cp $GOLDEN_DTB_PATH/*.dtb $GOLDEN_IMG_DIR/
                else
                    return 1
                fi
            else
                echo "$GOLDEN_OBSOLETE_CONFIG not detected"
                return 1
            fi
        popd > /dev/null
    else
         echo "SKIP build Golden Kernel."
    fi

    return 0
}

function kernel_external_modules_list_get()
{
    config_get TARGET_CHIP_ARCH || return 1
    if kernel_version_is_4p4 ; then
        KERNEL_VERSION_EX="kernel_4.4"
        PARAGONDIR=`platform_dir_get`/system/src/external/paragon/lke_9.4.4_b4
    elif kernel_version_is_4p1 ; then
        KERNEL_VERSION_EX="kernel_4.1"
        PARAGONDIR=`platform_dir_get`/system/src/external/paragon/lke_9.4.4_b303
    elif kernel_version_is_4p9 ; then
        KERNEL_VERSION_EX="kernel_4.9"
        if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
            PARAGONDIR=`platform_dir_get`/system/src/external/paragon/lke_9.6.4_b14
        else
            PARAGONDIR=`platform_dir_get`/system/src/external/paragon/lke_9.6.4_b5
        fi
    elif kernel_version_is_4p14 ; then
        KERNEL_VERSION_EX="kernel_4.14"
        if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
            PARAGONDIR=`platform_dir_get`/system/src/external/paragon/lke_9.6.4_b14
        else
            PARAGONDIR=`platform_dir_get`/system/src/external/paragon/lke_9.6.4_b5
        fi
    else
        KERNEL_VERSION_EX="kernel_3.10"
        PARAGONDIR=`platform_dir_get`/system/src/external/paragon
    fi

    DRIVERDIR=`platform_dir_get`/system/src/drivers
    MALIKODIR=$KERNELDIR/modules/mali
    OPTEEDIR=$KERNELDIR/drivers/optee_linuxdriver

    MODULES_LIST=
    [ -d "$MALIKODIR"   ] && list_add MODULES_LIST `find $MALIKODIR/    -name *.ko`
    [ -d "$PARAGONDIR"  ] && list_add MODULES_LIST `find $PARAGONDIR/   -name *.ko`
    [ -d "$DRIVERDIR"   ] && list_add MODULES_LIST `find $DRIVERDIR/    -name *.ko`
    [ -d "$KERNELDIR"   ] && list_add MODULES_LIST `find $KERNELDIR/    -name *.ko`
    [ -d "$OPTEEDIR"    ] && list_add MODULES_LIST `find $OPTEEDIR/     -name "optee*.ko"`

    [ "$1" != "" ] && export $1=${MODULES_LIST} || echo ${MODULES_LIST}
    return 0
}

function kernel_external_modules()
{
    kernel_external_modules_list_get

    PARAGONDIR=$PLATFORMDIR/system/src/external/paragon
    EXT_DRIVERS=$PLATFORMDIR/system/src/drivers
    OPTEE_DRIVERS=$KERNELDIR/drivers/optee_linuxdriver
    export KERNELDIR
    export KERNELTOOLCHAIN
    export KERNEL_VERSION
    export KERNEL_VERSION_EX
    export KERNEL_PATCHLEVEL
    export TARGET_CHIP_ARCH
    if [ "$KERNEL_TARGET_CHIP" = "phoenix" ]; then
        if [ -d "$KERNELDIR/modules/mali" ]; then
            pushd $KERNELDIR
            pushd modules
            if [ -d "mali" ]; then
                make -C mali -j $MULTI -l $LOAD_AVERAGE TARGET_KDIR=$KERNELDIR install
                ERR=$?
            fi
            popd
            popd
        fi
        [ "$ERR" = "0" ] || return $ERR;
        if [ -d "$OPTEE_DRIVERS" ]; then
            pushd $KERNELDIR
            make -j $MULTI -l $LOAD_AVERAGE M=$OPTEE_DRIVERS modules
            ERR=$?
            popd
        fi
        [ "$ERR" = "0" ] || return $ERR;
    fi

    if [ -d "$PARAGONDIR" ]; then
        pushd $PARAGONDIR > /dev/null
        make clean && make -j $MULTI -l $LOAD_AVERAGE
        ERR=$?
        popd > /dev/null
    fi

    if [ -d "$EXT_DRIVERS" ]; then
        pushd $EXT_DRIVERS > /dev/null
        config_get ANDROID_CODENAME
        make clean && make -j $MULTI -l $LOAD_AVERAGE ANDROID_VERSION=$ANDROID_CODENAME && make install
        ERR=$?
        popd > /dev/null
    fi

    return $ERR;
}

function kernel_clean()
{
    pushd $KERNELDIR
        build_cmd make clean
        test -d $GOLDEN_IMG_DIR && rm -r $GOLDEN_IMG_DIR
    popd
    return $ERR;
}

function kernel_check_toolchain()
{
    config_get KERNEL_TARGET_CHIP || return 1
    KERNELTOOLCHAIN_VERSION=
    case "$KERNEL_TARGET_CHIP" in
        phoenix)
            KERNELTOOLCHAIN_VERSION=arm-2013.11
            ;;
        kylin)
             if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                 KERNELTOOLCHAIN_VERSION=asdk64-4.9.4-a53-EL-3.10-g2.19-a64nt-160307
             else
                 KERNELTOOLCHAIN_VERSION=asdk-6.4.1-a53-EL-4.9-g2.26-a32nut-180831
             fi
            ;;
        hercules)
             if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                 KERNELTOOLCHAIN_VERSION=asdk-6.4.1-a55-EL-4.9-g2.26-a64nut-180426
             else
                 KERNELTOOLCHAIN_VERSION=asdk-6.4.1-a53-EL-4.9-g2.26-a32nut-180831
             fi
            ;;
        thor)
             if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                 KERNELTOOLCHAIN_VERSION=asdk-6.4.1-a55-EL-4.9-g2.26-a64nut-180426
             else
                 KERNELTOOLCHAIN_VERSION=asdk-6.4.1-a53-EL-4.9-g2.26-a32nut-180831
             fi
            ;;
        hank)
             if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                 KERNELTOOLCHAIN_VERSION=asdk-6.4.1-a55-EL-4.9-g2.26-a64nut-180426
             else
                 KERNELTOOLCHAIN_VERSION=asdk-6.4.1-a53-EL-4.9-g2.26-a32nut-180831
             fi
            ;;
    esac

    [ "$KERNELTOOLCHAIN_VERSION" = "" ] && return 2

    if ! platform_toolchain_checkout $KERNELTOOLCHAIN_VERSION KERNELTOOLCHAIN ;then
        echo "kernel toolchain $KERNELTOOLCHAIN_VERSION checkout failed!"
        return 3
    fi

    if [ ! -d "${KERNELTOOLCHAIN}/bin" ]; then
        echo "kernel toolchain dir (${KERNELTOOLCHAIN}/bin) not found!"
        return 4
    fi

    export KERNELTOOLCHAIN=${KERNELTOOLCHAIN}/bin
    export PATH=$KERNELTOOLCHAIN:$PATH
    return 0
}

function kernel_prepare_parameters()
{
    config_get KERNEL_TARGET_CHIP || return 1
    config_get TARGET_CHIP_ARCH || return 1

    [ "$KERNEL_TARGET_CHIP" = "" ] && return 2
    case "$KERNEL_TARGET_CHIP" in
        "phoenix")
            export ARCH=arm
            export CROSS_COMPILE="ccache arm-linux-gnueabihf-"
            export KERNEL_IMAGE=uImage
            export KERNEL_TARGET_VENDOR=""
            #export _CROSS=arm-linux-gnueabihf-
            ;;
        "kylin")
            if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                export ARCH=arm64
                export CROSS_COMPILE="ccache asdk64-linux-"
                export _CROSS="ccache asdk64-linux-"
            else
                export ARCH=arm
                export CROSS_COMPILE="ccache arm-linux-gnueabi-"
                export _CROSS="ccache arm-linux-gnueabi-"
            fi
            export KERNEL_IMAGE=Image
            export KERNEL_TARGET_VENDOR="realtek"
            ;;
        "hercules")
            if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                export ARCH=arm64
                export CROSS_COMPILE="ccache asdk64-linux-"
                export _CROSS="ccache asdk64-linux-"
            else
                export ARCH=arm
                export CROSS_COMPILE="ccache arm-linux-gnueabi-"
                export _CROSS="ccache arm-linux-gnueabi-"
            fi
            export KERNEL_IMAGE=Image
            export KERNEL_TARGET_VENDOR="realtek"
	    vmx_hardening_is_enable     && export ENABLE_VMX_HARDENING=YES || export ENABLE_VMX_HARDENING=NO
            ;;
        "thor")
             if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                 export ARCH=arm64
                 export CROSS_COMPILE="ccache asdk64-linux-"
                 export _CROSS="ccache asdk64-linux-"
             else
                 export ARCH=arm
                 export CROSS_COMPILE="ccache arm-linux-gnueabi-"
                 export _CROSS="ccache arm-linux-gnueabi-"
             fi
            export KERNEL_IMAGE=Image
            export KERNEL_TARGET_VENDOR="realtek"
            ;;
        "hank")
             if [ "$TARGET_CHIP_ARCH" = "arm64" ]; then
                 export ARCH=arm64
                 export CROSS_COMPILE="ccache asdk64-linux-"
                 export _CROSS="ccache asdk64-linux-"
             else
                 export ARCH=arm
                 export CROSS_COMPILE="ccache arm-linux-gnueabi-"
                 export _CROSS="ccache arm-linux-gnueabi-"
             fi
            export KERNEL_IMAGE=Image
            export KERNEL_TARGET_VENDOR="realtek"
            ;;
        *)
            echo -e "$0 \033[47;31mERROR! KERNEL_TARGET_CHIP($KERNEL_TARGET_CHIP) not found!\033[0m"
            exit 1
            ;;
    esac

    #export CCACHE=ccache
    #export AS=${CROSS_COMPILE}as
    #export LD=${CROSS_COMPILE}ld
    #export CC=${CCACHE}${CROSS_COMPILE}gcc
    #export AR=${CROSS_COMPILE}ar
    #export NM=${CROSS_COMPILE}nm
    #export STRIP=${CROSS_COMPILE}strip
    #export OBJCOPY=${CROSS_COMPILE}objcopy
    #export OBJDUMP=${CROSS_COMPILE}objdump

    return 0
}

function kernel_prepare()
{
    build_cmd kernel_checkout
    build_cmd kernel_version
    build_cmd kernel_prepare_parameters
    build_cmd kernel_config
    build_cmd kernel_check_toolchain
    build_cmd kernel_config_check
    return 0;
}
