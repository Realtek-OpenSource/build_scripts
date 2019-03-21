#!/bin/bash

[ "$ENV_IMAGE_SECURE_SOURCE" != "" ] && return
ENV_IMAGE_SECURE_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD

source $SCRIPTDIR/build_prepare.sh
source $SCRIPTDIR/env_bootcode_lk.sh

IMAGEDIR=$TOPDIR/image_file

function image_secure_type_is_off()
{
    config_get IMAGE_SECURE_OPTION || image_secure_config
    [ "$IMAGE_SECURE_OPTION" = "off" ] && return 0 || return 1
}

function image_secure_is_efuse_key()
{
    IMAGE_SECURE_EFUSE_KEY=
    config_get IMAGE_SECURE_EFUSE_KEY
    [ "$IMAGE_SECURE_EFUSE_KEY" = "true" ] && return 0 || return 1
}

function image_secure_is_efuse_fw()
{
    IMAGE_SECURE_EFUSE_FW=
    config_get IMAGE_SECURE_EFUSE_FW
    [ "$IMAGE_SECURE_EFUSE_FW" = "true" ] && return 0 || return 1
}

function image_secure_is_fw_table_sign()
{
    IMAGE_SECURE_FW_TABLE_SIGN=
    config_get IMAGE_SECURE_FW_TABLE_SIGN
    [ "$IMAGE_SECURE_FW_TABLE_SIGN" = "true" ] && return 0 || return 1
}

function image_secure_is_enc_ta()
{
    IMAGE_SECURE_ENC_TA=
    config_get IMAGE_SECURE_ENC_TA
    [ "$IMAGE_SECURE_ENC_TA" = "true" ] && return 0 || return 1
}

function image_secure_config()
{
    # remove old config name
    config_remove IMAGE_SECURE_INSTALL_BOOTLOADER
    config_remove IMAGE_SECURE_OFFLINE_GEN
    config_remove IMAGE_SECURE_CHIP_VERSION

    IMAGE_SECURE_OPTION_LIST=
    list_add IMAGE_SECURE_OPTION_LIST on
    list_add IMAGE_SECURE_OPTION_LIST off
    config_get_menu IMAGE_SECURE_OPTION IMAGE_SECURE_OPTION_LIST off

    if [ "$IMAGE_SECURE_OPTION" = "on" ]; then
        config_get_bool IMAGE_SECURE_EFUSE_KEY
        config_get_bool IMAGE_SECURE_EFUSE_FW
        config_get_bool IMAGE_SECURE_FW_TABLE_SIGN
        config_get_bool IMAGE_SECURE_ENC_TA
        config_get IMAGE_SECURE_KEY_DIR_OTHER
    else
        config_remove IMAGE_SECURE_EFUSE_KEY
        config_remove IMAGE_SECURE_EFUSE_FW
        config_remove IMAGE_SECURE_KEY_DIR_OTHER
        config_remove IMAGE_SECURE_FW_TABLE_SIGN
        config_remove IMAGE_SECURE_ENC_TA
    fi
}

function image_secure_key_dir_get()
{
    image_secure_item=$1
    IMAGE_SECURE_KEY_DIR_OTHER=
    config_get IMAGE_SECURE_KEY_DIR_OTHER
    if [ "$IMAGE_SECURE_KEY_DIR_OTHER" != "" ]; then
        dir=$IMAGE_SECURE_KEY_DIR_OTHER
    else
        #TODO uboot32/uboot64
        dir=`bootcode_lk_key_dir_get`
    fi
    [ "$image_secure_item" != "" ] && export ${image_secure_item}="${dir}" || echo ${dir}
}

function image_secure_efuse_tool_copy()
{
    ERR=0
    image_secure_type_is_off && return 0
    #TODO uboot32/uboot64
    src_dir=`bootcode_lk_tools_efuse_verify_out_dir_get`
    des_dir=$IMAGEDIR
    efuse_tools=
    if image_secure_is_efuse_key || image_secure_is_efuse_fw; then
        list_add efuse_tools efuse_verify.bin
        if [ "$IMAGE_TARGET_CHIP" == "thor" ]; then
            list_add efuse_tools otp_programmer.complete.enc
        else
            list_add efuse_tools efuse_programmer.complete.enc
        fi
    fi

    [ "$efuse_tools" = "" ] && return 0

    if [ ! -e "${des_dir}" ]; then
        echo "ERROR! [image_secure_efuse_tool_copy] $des_dir not found!"
        return 1
    fi

    for f in $efuse_tools
    do
        file=${src_dir}/${f}
        if [ ! -e "${file}" ]; then
            echo "ERROR! [image_secure_efuse_tool_copy] $file not found!"
            ERR=1
            continue
        fi
        cp -vf $file $des_dir/
    done
    return $ERR
}

function image_secure_key_copy()
{
    ERR=0

    if [ "${VMX_TYPE}" == "ultra" ] && vmx_is_enable_boot_flow && image_secure_type_is_off; then
        echo "none secure VMX ULTRA build"
    fi

    config_get VMX_TYPE

    if vmx_is_enable_boot_flow; then
        if [ "${VMX_TYPE}" == "ultra" ]; then
            echo "VMX ULTRA build, we do not copy key."
        else
            AES_KEY_LIST=
            list_add AES_KEY_LIST vmx_aes_128bit_key.bin
            list_add AES_KEY_LIST aes_128bit_ka.bin
            list_add AES_KEY_LIST aes_128bit_kc.bin
            list_add AES_KEY_LIST aes_128bit_kh.bin
            list_add AES_KEY_LIST aes_128bit_kx.bin
            RSA_KEY_LIST=
            list_add RSA_KEY_LIST vmx_rsa_key_2048.embed_bl.pem
        fi
    else
        AES_KEY_LIST=
        list_add AES_KEY_LIST aes_128bit_key_1.bin
        list_add AES_KEY_LIST aes_128bit_key_2.bin
        list_add AES_KEY_LIST aes_128bit_key_3.bin
        list_add AES_KEY_LIST aes_128bit_key.bin
        list_add AES_KEY_LIST aes_128bit_seed.bin
        RSA_KEY_LIST=
        list_add RSA_KEY_LIST rsa_key_2048.fw.pem
        list_add RSA_KEY_LIST rsa_key_2048.tee.pem
        if [ "$IMAGE_TARGET_CHIP" != "thor" ]; then
            list_add RSA_KEY_LIST rsa_key_2048.pem
            list_add RSA_KEY_LIST rsa_key_2048.pem.bin.rev
        fi
    fi
    src_dir=`image_secure_key_dir_get`
    des_dir=$IMAGEDIR

    if [ ! -e "${des_dir}" ]; then
        echo "ERROR! [image_secure_key_copy] $des_dir not found!"
        return 1
    fi

    for f in $AES_KEY_LIST $RSA_KEY_LIST
    do
        file=${src_dir}/${f}
        if [ ! -e "${file}" ]; then
            echo "ERROR! [image_secure_key_copy] $file not found!"
            ERR=1
            continue
        fi
        cp -vf $file $des_dir/
    done
    return $ERR
}

function image_secure_prepare()
{
    if [ "${VMX_TYPE}" == "ultra" ] && vmx_is_enable_boot_flow && image_secure_type_is_off; then
        echo "VMX Ultra case, we do not copy key.!"
        return 0
    fi
    if image_secure_type_is_off; then
        if [ -e $SCRIPTDIR/lk/ ] && [ "$IMAGE_TARGET_CHIP" = "kylin" ]; then
            build_cmd image_secure_key_copy
        fi
    else
        build_cmd image_secure_key_copy
        build_cmd image_secure_efuse_tool_copy
    fi
}
