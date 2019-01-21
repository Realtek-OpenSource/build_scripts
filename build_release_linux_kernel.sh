#!/bin/bash

NCPU=`grep processor /proc/cpuinfo | wc -l`
MULTI=`expr $NCPU + 2`

SCRIPTDIR=$PWD
KERNELDIR=$SCRIPTDIR/linux-kernel
PHOENIXDIR=$SCRIPTDIR/phoenix
TOOLCHAINDIR=$PHOENIXDIR/toolchain
ERR=0

#------------------------------
source $SCRIPTDIR/build_prepare.sh

config_get CUSTOMER
config_get GIT_SERVER_URL
config_get SDK_BRANCH
config_get USER
config_get USE_RTK_REPO
config_get BUILDTYPE_ANDROID
config_get KERNEL_DEF_CONFIG
#MODULE_PATH=$ANDROIDDIR/out/target/product/$BUILDTYPE_ANDROID/system/vendor/modules
MODULE_PATH=$ANDROIDDIR/out/target/product/$BUILDTYPE_ANDROID/vendor/modules


#------------------------------

#export CCACHE=ccache
export ARCH=arm
export CROSS_COMPILE="ccache arm-linux-gnueabi-"
export _CROSS=arm-linux-gnueabi-
export KERNEL_IMAGE=Image
export KERNEL_TARGET_VENDOR="realtek"
#export AS=${CROSS_COMPILE}as
#export LD=${CROSS_COMPILE}ld
#export CC=${CCACHE}${CROSS_COMPILE}gcc
#export AR=${CROSS_COMPILE}ar
#export NM=${CROSS_COMPILE}nm
#export STRIP=${CROSS_COMPILE}strip
#export OBJCOPY=${CROSS_COMPILE}objcopy
#export OBJDUMP=${CROSS_COMPILE}objdump

export PATH=$TOOLCHAINDIR/asdk-6.4.1-a53-EL-4.9-g2.26-a32nut-180831/bin:$PATH

KERNELTOOLCHAIN=$TOOLCHAINDIR/asdk-6.4.1-a53-EL-4.9-g2.26-a32nut-180831/bin
KERNEL_TARGET_CHIP=hercules
ARCH_DIR=arm


PARAGONDIR=$PHOENIXDIR/system/src/external/paragon
EXT_DRIVERS=$PHOENIXDIR/system/src/drivers

KERNEL_TARGET_CHIP_LIST="phoenix kylin"


#------------------------------
build_kernel_init()
{
    [ ! -d "$KERNELDIR" ] && mkdir $KERNELDIR
    pushd $KERNELDIR > /dev/null
                if [ "$USE_RTK_REPO" == true ]; then
                        repo init -u ssh://$USER@$GIT_SERVER_URL:29418/$CUSTOMER/manifests -b $SDK_BRANCH -m linux-kernel.xml --repo-url=ssh://$USER@$GIT_SERVER_URL:29418/git-repo
                else
                        repo init -u ssh://$USER@$GIT_SERVER_URL:29418/$CUSTOMER/manifests -b $SDK_BRANCH -m linux-kernel.xml
                fi
        popd

        [ ! -d "$PLATFORMDIR" ] && mkdir $PLATFORMDIR
        pushd $PLATFORMDIR > /dev/null
                if [ "$USE_RTK_REPO" == true ]; then
                        repo init -u ssh://$USER@$GIT_SERVER_URL:29418/$CUSTOMER/manifests -b $SDK_BRANCH -m phoenix.xml --repo-url=ssh://$USER@$GIT_SERVER_URL:29418/git-repo
                else
                        repo init -u ssh://$USER@$GIT_SERVER_URL:29418/$CUSTOMER/manifests -b $SDK_BRANCH -m phoenix.xml
                fi
        popd

        return 0

}

sync_kernel()
{
    pushd $KERNELDIR > /dev/null
        repo sync
        ERR=$?
                [ "$ERR" = "0" ] && > .repo_ready
        git status -s | grep -v "^??"
    popd > /dev/null
        pushd $PLATFORMDIR > /dev/null
                repo sync
        popd
   return $ERR;
}

checkout_kernel()
{
    if [ ! -e "$KERNELDIR/.repo_ready" ]; then
                build_kernel_init
                sync_kernel
    fi
    return $ERR;
}
#------------------------------




build_kernel()
{
    BUILD_PARAMETERS=$*
    pushd $KERNELDIR > /dev/null
        make -j $MULTI $BUILD_PARAMETERS DTC_FLAGS="-p 8192 -@" DTC="$PLATFORMDIR/toolchain/dtb_overlay_tool/dtc"
        ERR=$?
    popd > /dev/null
    return $ERR
}
function build_cmd()
{
    $@
    ERR=$?
    printf "$* "
    if [ "$ERR" != "0" ]; then
        echo -e "\033[47;31m [ERROR] $ERR \033[0m"
        exit 1
    else
        echo "[OK]"
    fi
}

build_external_modules()
{
    export KERNELDIR
    export KERNELTOOLCHAIN
if [ "$KERNEL_TARGET_CHIP" = "phoenix" ]; then
    if [ -d "$KERNELDIR/modules/mali" ]; then
    pushd $KERNELDIR
        pushd modules
            if [ -d "mali" ]; then
                make -C mali -j $MULTI TARGET_KDIR=$KERNELDIR install
                ERR=$?
            fi
        popd
    popd
    fi
    [ "$ERR" = "0" ] || return $ERR;
    if [ -d "$OPTEE_DRIVERS" ]; then
        pushd $KERNELDIR
            make -j $MULTI M=$OPTEE_DRIVERS modules
            ERR=$?
        popd
    fi
    [ "$ERR" = "0" ] || return $ERR;
fi
    if [ -d "$PARAGONDIR" ]; then
        pushd $PARAGONDIR > /dev/null
            make clean && make -j $MULTI
            ERR=$?
        popd > /dev/null
    fi
    if [ -d "$EXT_DRIVERS" ]; then
        pushd $EXT_DRIVERS > /dev/null
            make clean && make -j $MULTI ANDROID_VERSION=$RTK_ANDROID_VERSION && make install
            ERR=$?
        popd > /dev/null
    fi

    return $ERR;
}

function kernel_dtboimg()
{
        DTBO_DIR=$KERNELDIR/arch/$ARCH_DIR/boot/dts/realtek/rtd139x/dtbo
        DTBOCFG=${DTBO_DIR}/rtd-139x-dtboimg.cfg

    pushd $DTBO_DIR > /dev/null
        DTC=$PHOENIXDIR/toolchain/dtb_overlay_tool/dtc
        MKDTIMG=$PHOENIXDIR/toolchain/dtb_overlay_tool/mkdtimg
        for d in *.dts; do
            DTBO_NAME=${d:0:-4}
            $DTC -W no-unit_address_vs_reg -@ -a 4 -O dtb -o ${DTBO_NAME}.dtbo $d
        done
        $MKDTIMG cfg_create ${DTBOCFG:0:-12}.dtboimg ${DTBOCFG}
    popd > /dev/null


}

clean_kernel()
{
    pushd $KERNELDIR
        build_cmd make clean
    popd
    return $ERR;
}


if [ "$1" = "" ]; then
    echo "$0 commands are:"
    echo "    checkout    "
    echo "    build       "
    echo "    clean       "
else
    while [ "$1" != "" ]
    do
        case "$1" in
	    checkout)
		build_cmd checkout_kernel
		;;
            build)
                build_cmd build_kernel $KERNEL_IMAGE modules dtbs
                build_cmd kernel_dtboimg
                build_cmd build_external_modules
                ;;
            clean)
                build_cmd clean_kernel
                ;;
	    sync)
		build_cmd sync_kernel
		;;
            *)
                echo -e "$0 \033[47;31mUnknown CMD: $1\033[0m"
                exit 1
                ;;
        esac
        shift 1
    done
fi

exit $ERR
