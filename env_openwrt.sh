#!/bin/bash
[ "$ENV_OPENWRT_SOURCE" != "" ] && return
ENV_OPENWRT_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh

OPENWRT_SUPDIR=$TOPDIR/openwrt

function openwrt_dir_get()
{
    item=$1
    dir=$OPENWRT_SUPDIR
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function openwrt_init()
{
    [ ! -d "$OPENWRT_SUPDIR" ] && mkdir $OPENWRT_SUPDIR
    pushd $OPENWRT_SUPDIR > /dev/null
    repo init -u $GERRIT_MANIFEST -b $BRANCH_PARENT/$BRANCH_QA_TARGET -m openwrt.xml $REPO_PARA
    ERR=$?
    popd > /dev/null
    return $ERR;
}

function openwrt_sync()
{
    ERR=0
    if [ -d "$OPENWRT_SUPDIR" ]; then
        pushd $OPENWRT_SUPDIR > /dev/null
        repo sync --force-sync
        ERR=$?
        popd > /dev/null
    else
        ERR=1
    fi
    return $ERR
}

function openwrt_checkout()
{
    ERR=0
    if [ ! -e "${OPENWRT_SUPDIR}/.repo_ready" ]; then
        openwrt_init && openwrt_sync && (> ${OPENWRT_SUPDIR}/.repo_ready) || ERR=1
    fi
    return $ERR
}
