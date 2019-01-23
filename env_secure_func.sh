#!/bin/bash
[ "$ENV_SECURE_FUNCTION_SOURCE" != "" ] && return
ENV_SECURE_FUNCTION_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
source $SCRIPTDIR/env_image_secure.sh
ERR=0

function secure_func_config()
{
    # remove old config name
    config_remove DMVERITY_ENABLE
    config_remove DTB_ENC
    config_remove TEE_FW
    config_remove SECURE_FUNC_TEE_FW

    config_get_bool SECURE_FUNC_DMVERITY_ENABLE false

    if ! image_secure_type_is_off ; then
        config_get_bool SECURE_FUNC_DTB_ENC false
    else
        config_remove SECURE_FUNC_DTB_ENC
    fi
}

function secure_func_dmverity_is_enable()
{
    config_get SECURE_FUNC_DMVERITY_ENABLE
    [ "$SECURE_FUNC_DMVERITY_ENABLE" = "true" ] && return 0 || return 1
}

function secure_func_dtb_enc_is_enable()
{
    image_secure_type_is_off && return 1
    config_get SECURE_FUNC_DTB_ENC
    [ "$SECURE_FUNC_DTB_ENC" = "true" ] && return 0 || return 1
}

