#!/bin/bash
[ "$ENV_PLATFORM_SOURCE" != "" ] && return
ENV_PLATFORM_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh

PLATFORMDIR=$TOPDIR/phoenix
TOOLCHAINDIR=$PLATFORMDIR/toolchain

function platform_dir_get()
{
    item=$1
    dir=$PLATFORMDIR
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function platform_toolchain_dir_get()
{
    item=$1
    dir=$TOOLCHAINDIR
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function platform_init()
{
    [ ! -d "$PLATFORMDIR" ] && mkdir $PLATFORMDIR
    pushd $PLATFORMDIR > /dev/null
    repo init -u $GERRIT_MANIFEST -b master -m phoenix.xml $REPO_PARA
    popd > /dev/null
    return 0
}

function platform_sync()
{
    ERR=0
    if [ -d "$PLATFORMDIR" ]; then
        pushd $PLATFORMDIR
            repo sync --force-sync
            ERR=$?
        popd > /dev/null
    else
        ERR=1
    fi
    return $ERR
}

# platform_toolchain_check {ToolchainName} {export patch}
# ex:
#   platform_toolchain_check android-ndk-r9c ANDROID_NDK_PATH
#   if platform_toolchain_check android-ndk-r9c ANDROID_NDK_PATH; then
#       echo ANDROID_NDK_PATH=$ANDROID_NDK_PATH
#   fi
function platform_toolchain_checkout()
{
    TOOLCHAIN_TARGET=$1
    [ "$TOOLCHAIN_TARGET" = "" ] && return 1

    TOOLCHAIN_ITEM=$2

    TOOLCHAIN_LIST=
    list_add TOOLCHAIN_LIST arm-2013.10
    list_add TOOLCHAIN_LIST arm-2013.11
    list_add TOOLCHAIN_LIST android-ndk-r10e
    list_add TOOLCHAIN_LIST android-ndk-r11c
    list_add TOOLCHAIN_LIST android-ndk-r15c
    list_add TOOLCHAIN_LIST android-ndk-r9c
    list_add TOOLCHAIN_LIST android-ndk-r17c
    list_add TOOLCHAIN_LIST asdk64-4.9.3-a53-EL-3.10-g2.19-a64nt-150615
    list_add TOOLCHAIN_LIST asdk64-4.9.4-a53-EL-3.10-g2.19-a64nt-160307
    list_add TOOLCHAIN_LIST asdk-6.4.1-a55-EL-4.9-g2.26-a64nut-180426
    list_add TOOLCHAIN_LIST asdk-6.4.1-a53-EL-4.9-g2.26-a32nut-180831
    list_add TOOLCHAIN_LIST rsdk-1.5.5

    found=0
    for t in $TOOLCHAIN_LIST
    do
        if [ "$t" == "$TOOLCHAIN_TARGET" ]; then
            found=1
            break
        fi
    done

    if [ "$found" != "1" ]; then
        echo "Toolchain: $TOOLCHAIN_TARGET not found!"
        return 2
    fi

    TOOLCHAIN_TARGET_DIR=`platform_toolchain_dir_get`/$TOOLCHAIN_TARGET


    if [ -d "$TOOLCHAIN_TARGET_DIR" ]; then
        [ "$TOOLCHAIN_ITEM" != "" ] && export ${TOOLCHAIN_ITEM}="${TOOLCHAIN_TARGET_DIR}" || echo $TOOLCHAIN_TARGET_DIR
        return 0
    fi

    TOOLCHAIN_PROJECT=RTD_DHC/system/toolchain/${TOOLCHAIN_TARGET}

    config_get_text MIRROR_LOCATION
    TOOLCHAIN_MIRROR_LOCATION_DIR="${MIRROR_LOCATION}/${TOOLCHAIN_PROJECT}.git"
    if [ -d "$TOOLCHAIN_MIRROR_LOCATION_DIR" ]; then
        TOOLCHAIN_REFERENCE=--reference=${TOOLCHAIN_MIRROR_LOCATION_DIR}
    else
        TOOLCHAIN_REFERENCE=
    fi

    git clone ${GERRIT_SERVER}/${TOOLCHAIN_PROJECT} ${TOOLCHAIN_TARGET_DIR} ${TOOLCHAIN_REFERENCE} > /dev/null  2>&1
    [ "$?" != "0" ] && return 3
    [ "$TOOLCHAIN_ITEM" != "" ] && export ${TOOLCHAIN_ITEM}="${TOOLCHAIN_TARGET_DIR}" || echo $TOOLCHAIN_TARGET_DIR
    return 0
}

function platform_checkout()
{
    [ -e "$PLATFORMDIR/.repo_ready" ] && return 0
    platform_init && platform_sync && (> $PLATFORMDIR/.repo_ready) || return 1
    return 0
}
