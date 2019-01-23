#!/bin/bash
[ "$ENV_BOOTCODE_SOURCE" != "" ] && return
ENV_BOOTCODE_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh

source $SCRIPTDIR/env_bootcode_lk.sh

function bootcode_export_version_get()
{
    version=
    #TODO
    version="N/A"

    [ "$1" != "" ] && export $1=${version} || echo ${version}
    return 0
}

function bootcode_init()
{
    return 0
}

function bootcode_config()
{
    BOOTCODE_OPTION_LIST=
    list_add BOOTCODE_OPTION_LIST off
    list_add BOOTCODE_OPTION_LIST lk
    #list_add BOOTCODE_OPTION_LIST uboot
    config_get_menu BOOTCODE_OPTION BOOTCODE_OPTION_LIST lk

    if [ "$BOOTCODE_OPTION" = "lk" ]; then
        if ! config_get BOOTCODE_LK_OPTION || [ "$BOOTCODE_LK_OPTION" != "on" ]; then
            config_set BOOTCODE_LK_OPTION on
        fi
    else
        if ! config_get BOOTCODE_LK_OPTION || [ "$BOOTCODE_LK_OPTION" != "off" ]; then
            config_set BOOTCODE_LK_OPTION off
        fi
    fi
    bootcode_lk_config
    return 0
}

function bootcode_type_is_off()
{
    config_get BOOTCODE_OPTION || bootcode_config
    [ "$BOOTCODE_OPTION" = "off" ] && return 0 || return 1
}

function bootcode_type_is_lk()
{
    config_get BOOTCODE_OPTION || bootcode_config
    [ "$BOOTCODE_OPTION" = "lk" ] && return 0 || return 1
}

function bootcode_type_is_uboot()
{
    config_get BOOTCODE_OPTION || bootcode_config
    [ "$BOOTCODE_OPTION" = "uboot" ] && return 0 || return 1
}

function bootcode_checkout()
{
    bootcode_type_is_off && return 0
    bootcode_type_is_lk && bootcode_lk_checkout
    return 0
}

function bootcode_build()
{
    bootcode_type_is_off && return 0
    bootcode_type_is_lk && bootcode_lk_build
    return 0
}

function bootcode_sync()
{
    bootcode_type_is_off && return 0
    bootcode_type_is_lk && bootcode_lk_sync
    return 0
}
