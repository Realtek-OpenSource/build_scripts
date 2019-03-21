#!/bin/bash
[ "$ENV_XEN_SOURCE" != "" ] && return
ENV_XEN_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
ERR=0

function xen_config()
{
    config_get_bool XEN_ENABLE false
}

function xen_is_enable()
{
    xen_config
    config_get XEN_ENABLE
    [ "$XEN_ENABLE" = "true" ] && return 0 || return 1
}
