#!/bin/bash
[ "$ENV_CA_SOURCE" != "" ] && return
ENV_CA_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
#source $SCRIPTDIR/env_qa_sub.sh
#source $SCRIPTDIR/env_android.sh
#source $SCRIPTDIR/env_vmx.sh
source $SCRIPTDIR/env_ca_nagxx.sh

function ca_config()
{
    CONFIG_LIST=
    list_add CONFIG_LIST none
    list_add CONFIG_LIST nocs32
    config_get_menu CA_TYPE CONFIG_LIST none
    
}
ca_config

# Under Construction
function ca_sub_config()
{
    config_get CA_TYPE
    echo $CA_TYPE

    if [ "$CA_TYPE" == "nocs32" ]; then
        nagxx_config
    #elif []; then
    #else
    fi
}
#ca_sub_config

#nocs
#0: enable
#1: disable
function ca_is_nocs_enable()
{
	config_get CA_TYPE
	[ "$CA_TYPE" = "nocs32" ] && return 0 || return 1
	
}

