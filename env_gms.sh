#!/bin/bash

[ "$ENV_GMS_SOURCE" != "" ] && return
ENV_GMS_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
source $SCRIPTDIR/env_android.sh

GMS_DIR=$TOPDIR/gms


function gms_dir_get()
{
    gms_item=$1
    dir=$GMS_DIR
    [ "$gms_item" != "" ] && export ${gms_item}="${dir}" || echo ${dir}
    return 0
}

function gms_init()
{
    gms_type_is_off && return 0
    [ ! -d "$GMS_DIR" ] && mkdir $GMS_DIR
    pushd $GMS_DIR > /dev/null
    repo init -u $GERRIT_MANIFEST -b $BRANCH_PARENT/$BRANCH_QA_TARGET -m gms.xml $REPO_PARA
    ERR=$?
    popd > /dev/null
    return $ERR;
}

function gms_sync()
{
    gms_type_is_off && return 0
    ERR=0
    if [ -d "$GMS_DIR" ]; then
        pushd $GMS_DIR > /dev/null
        repo sync --force-sync
        ERR=$?
        popd > /dev/null
    else
        ERR=1
    fi
    return $ERR
}

function gms_checkout()
{
    gms_type_is_off && return 0
    ERR=0
    if [ ! -e "${GMS_DIR}/.repo_ready" ]; then
        gms_init && gms_sync && (> ${GMS_DIR}/.repo_ready) || ERR=1
    fi
    return $ERR
}

function gms_sub_list_get()
{
    gms_item=$1
    GMS_SUB_LIST=
    list_add GMS_SUB_LIST tablet
    list_add GMS_SUB_LIST tv-arm
    list_add GMS_SUB_LIST tv-arm64
    [ "$gms_item" != "" ] && export ${gms_item}="${GMS_SUB_LIST}" || echo "${GMS_SUB_LIST}"
    return 0
}

function gms_config()
{

    GMS_OPTION_LIST=
    list_add GMS_OPTION_LIST off
    list_add GMS_OPTION_LIST on
    config_get_menu     GMS_OPTION    GMS_OPTION_LIST   off

    if [ "$GMS_OPTION" = "on" ]; then
        gms_sub_list_get GMS_REPOSITORY_LIST
        GMS_REPOSITORY_DEFAULT=tablet
        config_get_menu GMS_REPOSITORY GMS_REPOSITORY_LIST $GMS_REPOSITORY_DEFAULT
    else
        config_remove GMS_REPOSITORY
    fi
}

function gms_type_is_off()
{
    config_get GMS_OPTION || gms_config
    [ "$GMS_OPTION" = "off" ] && return 0 || return 1
}

function gms_setup_environment()
{
    vendor_dir=`android_dir_get`/vendor

    if [ -d "$vendor_dir" ]; then
        for f in google
        do
            [ -e "$vendor_dir/$f" ] && rm -rf $vendor_dir/$f
        done
    fi

    gms_type_is_off && return 0

    if ! config_get GMS_REPOSITORY ; then
        echo "ERROR! GMS_REPOSITORY not found!"
        return 1
    fi

    [ ! -d "$vendor_dir" ] && mkdir -p $vendor_dir

    gms_repository_dir=${GMS_DIR}/${GMS_REPOSITORY}

    if [ ! -d "${gms_repository_dir}" ] ; then
        echo "ERROR! ${gms_repository_dir} not found!"
        return 1
    fi

    pushd $vendor_dir > /dev/null
        # using symbolic links may cause SearchLauncher path error, use hard links instead
        #ln -s ${gms_repository_dir}/google google
        cp -al ${gms_repository_dir}/google google 
    popd > /dev/null
    return 0
}
