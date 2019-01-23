#!/bin/bash
[ "$ENV_RTKSRC_SOURCE" != "" ] && return
ENV_RTKSRC_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
source $SCRIPTDIR/env_ca.sh

source $SCRIPTDIR/env_platform.sh

RTKSRC=$TOPDIR/software_Phoenix_RTK

function rtksrc_export_version_get()
{
    version=

    if config_get_true TARGET_BUILD_DVDPLAYER && [ -d "$RTKSRC/system" ]; then
        pushd $RTKSRC/system > /dev/null
            version=`git log --pretty=format:'%h' -n 1`
        popd > /dev/null
    else
        version="N/A"
    fi

    [ "$1" != "" ] && export $1=${version} || echo ${version}
    return 0
}

function rtksrc_dir_get()
{
    item=$1
    dir=$RTKSRC
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function rtksrc_init()
{
    [ ! -d "$RTKSRC" ] && mkdir $RTKSRC
    pushd $RTKSRC > /dev/null
    repo init -u $GERRIT_MANIFEST -b $BRANCH_PARENT/$BRANCH_QA_TARGET -m software_Phoenix_RTK.xml $REPO_PARA
    ERR=$?
    popd > /dev/null
    return $ERR
}

function rtksrc_sync
{
    ERR=0
    if [ -d "$RTKSRC" ]; then
        pushd $RTKSRC > /dev/null
        repo sync --force-sync
        ERR=$?
        popd > /dev/null
    else
        ERR=1
    fi
    return $ERR
}

function rtksrc_checkout
{
    ERR=0
    if [ ! -e "$RTKSRC/.repo_ready" ]; then
        rtksrc_init && rtksrc_sync && (> $RTKSRC/.repo_ready) || ERR=1
    fi
    return $ERR
}

# ex1 rtksrc_check_toolchain
# ex2 rtksrc_check_toolchain android-ndk-r11c
function rtksrc_check_toolchain()
{
    RTKSRC_ANDROID_NDK=$1
    [ "$RTKSRC_ANDROID_NDK" = "" ] && RTKSRC_ANDROID_NDK=android-ndk-r9c
    if [ "$BRANCH_PARENT" = "android-9.0.0-b" ]; then
        RTKSRC_ANDROID_NDK=android-ndk-r17c
    fi
    if ! platform_toolchain_checkout $RTKSRC_ANDROID_NDK RTKSRC_TOOLCHAINDIR; then
        echo "toolchain ($RTKSRC_ANDROID_NDK) checkout failed!"
        return 1
    fi

    if [ ! -d "${RTKSRC_TOOLCHAINDIR}" ]; then
        echo -e "\033[47;31m [ERROR] toolchain for rtksrc not found: $RTKSRC_TOOLCHAINDIR \033[0m"
        return 2
    fi

    export NDKROOT=${RTKSRC_TOOLCHAINDIR}
    export TOOLCHAIN_ROOT=$NDKROOT/toolchains/arm-linux-androideabi-4.8/prebuilt/linux-x86_64/bin
    if [ "$RTKSRC_ANDROID_NDK" == "android-ndk-r17c" ]; then
        export TOOLCHAIN_ROOT=$NDKROOT/toolchains/arm-linux-androideabi-4.9/prebuilt/linux-x86_64/bin
    fi
    export PATH=${TOOLCHAIN_ROOT}:$PATH
    return 0
}

function rtksrc_build_prepare()
{
    config_get KERNEL_TARGET_CHIP
    case "$KERNEL_TARGET_CHIP" in
        phoenix)
            common_include=include_1195
            ;;
        unicorn)
            common_include=include_1192
            ;;
        kylin)
            common_include=include_1295
            ;;
        hercules)
            common_include=include_1395
            ;;
        thor)
            common_include=include_1619
            ;;
        *)
            common_include=include_1195
            ;;
    esac

    [ -e $RTKSRC/common/include ] && rm $RTKSRC/common/include
    ln -s $common_include $RTKSRC/common/include
    return 0
}
