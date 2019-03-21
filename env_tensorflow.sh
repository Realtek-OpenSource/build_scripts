#!/bin/bash
[ "$ENV_TENSORFLOW_SOURCE" != "" ] && return
ENV_TENSORFLOW_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh

source $SCRIPTDIR/env_android.sh
source $SCRIPTDIR/env_kernel.sh

ERR=0

TF_DIR=$TOPDIR/tensorflow

function tf_init()
{
    tf_type_is_off && return 0
    [ ! -d "$TF_DIR" ] && mkdir $TF_DIR
    pushd $TF_DIR > /dev/null
    repo init -u $GERRIT_MANIFEST -b $BRANCH_PARENT/$BRANCH_QA_TARGET -m tensorflow.xml $REPO_PARA
    ERR=$?
    popd > /dev/null
    return $ERR;
}

function tf_sync()
{
    tf_type_is_off && return 0
    ERR=0
    if [ -d "$TF_DIR" ]; then
        pushd $TF_DIR > /dev/null
        repo sync --force-sync
        ERR=$?
        popd > /dev/null
    else
        ERR=1
    fi
    return $ERR
}

function tf_checkout()
{
    tf_type_is_off && return 0
    ERR=0
    if [ ! -e "${TF_DIR}/.repo_ready" ]; then
        tf_init && tf_sync && (> ${TF_DIR}/.repo_ready) || ERR=1
    fi
    return $ERR
}

function tf_config()
{
    config_get BRANCH_QA_TARGET
    TF_OPTION_LIST=
    list_add TF_OPTION_LIST off
    list_add TF_OPTION_LIST on
    case "$BRANCH_QA_TARGET" in
        trunk-8.1-b/kylin)
            config_get_menu     TENSOR_FLOW_CHECKOUT    TF_OPTION_LIST   off
            ;;
        *)
            config_set TENSOR_FLOW_CHECKOUT off
            ;;
    esac
}

function tf_type_is_off()
{
    config_get TENSOR_FLOW_CHECKOUT || tf_config
    [ "$TENSOR_FLOW_CHECKOUT" = "off" ] && return 0 || return 1
}

