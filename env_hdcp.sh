#!/bin/bash
[ "$ENV_HDCP_SOURCE" != "" ] && return
ENV_HDCP_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
ERR=0

function hdcp_config()
{
    config_get_bool HDCP_ENABLE false
    if [ "$HDCP_ENABLE" = "true" ]; then
        HDCP_TX_LIST=
        list_add HDCP_TX_LIST only-1.x
        list_add HDCP_TX_LIST only-2.2
        list_add HDCP_TX_LIST both-1.x-2.2
        config_get_menu HDCP_TX_VERSION HDCP_TX_LIST both-1.x-2.2

        case "$HDCP_TX_VERSION" in
            only-1.x)
                config_get_true HDCP_TX_1PX_EN  || config_set HDCP_TX_1PX_EN true
                config_get_false HDCP_TX_2P2_EN || config_set HDCP_TX_2P2_EN false
                ;;
            only-2.2)
                config_get_false HDCP_TX_1PX_EN || config_set HDCP_TX_1PX_EN false
                config_get_true HDCP_TX_2P2_EN  || config_set HDCP_TX_2P2_EN true
                ;;
            both-1.x-2.2)
                config_get_true HDCP_TX_1PX_EN  || config_set HDCP_TX_1PX_EN true
                config_get_true HDCP_TX_2P2_EN  || config_set HDCP_TX_2P2_EN true
                ;;
        esac

        config_get_bool HDCP_TX_IN_TEE false

        HDCP_RX_LIST=
        list_add HDCP_RX_LIST none
        list_add HDCP_RX_LIST only-1.x
        list_add HDCP_RX_LIST both-1.x-2.2
        config_get_menu HDCP_RX_VERSION HDCP_RX_LIST none

        case "$HDCP_RX_VERSION" in
            none)
                config_set HDCP_RX_1PX_EN false
                config_set HDCP_RX_2P2_EN false
                ;;
            only-1.x)
                config_set HDCP_RX_1PX_EN true
                config_set HDCP_RX_2P2_EN false
                ;;
            both-1.x-2.2)
                config_set HDCP_RX_1PX_EN true
                config_set HDCP_RX_2P2_EN true
                ;;
        esac

        if [ "$HDCP_RX_VERSION" = "none" ]; then
            config_set HDCP_RX_IN_TEE false
        else
            config_get_bool HDCP_RX_IN_TEE false
        fi

    else
        config_remove HDCP_TX_VERSION
        config_remove HDCP_RX_VERSION
        config_remove HDCP_TX_1PX_EN
        config_remove HDCP_TX_2P2_EN
        config_remove HDCP_RX_1PX_EN
        config_remove HDCP_RX_2P2_EN
        config_remove HDCP_TX_IN_TEE
        config_remove HDCP_RX_IN_TEE
    fi
}

function hdcp_is_enable()
{
    hdcp_config
    config_get HDCP_ENABLE
    [ "$HDCP_ENABLE" = "true" ] && return 0 || return 1
}

function hdcp_tx_1px_en()
{
    hdcp_is_enable || return 1
    config_get HDCP_TX_1PX_EN
    [ "$HDCP_TX_1PX_EN" = "true" ] && return 0 || return 1
}

function hdcp_tx_2p2_en()
{
    hdcp_is_enable || return 1
    config_get HDCP_TX_2P2_EN
    [ "$HDCP_TX_2P2_EN" = "true" ] && return 0 || return 1
}

function hdcp_tx_tee_en()
{
    hdcp_is_enable || return 1
    config_get HDCP_TX_IN_TEE
    [ "$HDCP_TX_IN_TEE" = "true" ] && return 0 || return 1
}

function hdcp_rx_1px_en()
{
    hdcp_is_enable || return 1
    config_get HDCP_RX_1PX_EN
    [ "$HDCP_RX_1PX_EN" = "true" ] && return 0 || return 1
}

function hdcp_rx_2p2_en()
{
    hdcp_is_enable || return 1
    config_get HDCP_RX_2P2_EN
    [ "$HDCP_RX_2P2_EN" = "true" ] && return 0 || return 1
}

function hdcp_rx_tee_en()
{
    hdcp_is_enable || return 1
    config_get HDCP_RX_IN_TEE
    [ "$HDCP_RX_IN_TEE" = "true" ] && return 0 || return 1
}

function hdcp_tx_copy_ta()
{
    if [ "`android_sdk_version_get |sed 's/\..*$//g'`" -ge "8" ]; then
        ANDROID_SYSTEM_DIR=`android_vendor_dir_get`
    else
        ANDROID_SYSTEM_DIR=`android_system_dir_get`
    fi

    config_get KERNEL_TARGET_CHIP
    config_get ANDROID_PRODUCT

    if [ "$KERNEL_TARGET_CHIP" = "hercules" ] || [ ${ANDROID_PRODUCT:0:12} = "rtk_hercules" ]; then
        QA_SUPPLEMENT_HDCP=${SCRIPTDIR}/qa_supplement/hdcp/hercules/
    elif [ "$KERNEL_TARGET_CHIP" = "kylin" ] || [ ${ANDROID_PRODUCT:0:9} = "rtk_kylin" ]; then
        QA_SUPPLEMENT_HDCP=${SCRIPTDIR}/qa_supplement/hdcp/kylin/
    else
        QA_SUPPLEMENT_HDCP=${SCRIPTDIR}/qa_supplement/hdcp/kylin/
    fi

    if [ "$VMX_CONFIG" = "false" ] || [ "$KERNEL_TARGET_CHIP" = "kylin" ]; then
	[ ! -d "${ANDROID_SYSTEM_DIR}/lib/teetz" ] && mkdir -p ${ANDROID_SYSTEM_DIR}/lib/teetz
	cp -rf ${QA_SUPPLEMENT_HDCP}/hdcp14_tx/*.ta* ${ANDROID_SYSTEM_DIR}/lib/teetz/
	cp -rf ${QA_SUPPLEMENT_HDCP}/hdcp2.2_tx/*.ta* ${ANDROID_SYSTEM_DIR}/lib/teetz/
    fi
}
