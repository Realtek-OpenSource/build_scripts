#!/bin/bash
[ "$ENV_CA_NAGXX_SOURCE" != "" ] && return
ENV_CA_NAGXX_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh

# Under Construction
function nagxx_config()
{
    echo "nagxx_config"
    
    #CONFIG_LIST=
    #list_add CONFIG_LIST x1
    #list_add CONFIG_LIST x2
    #list_add CONFIG_LIST x3
    #config_get_menu CA_NAGXX_XXXX CONFIG_LIST x1
}

function melon_is_drm_enable()
{
	config_get DRM_OPTION
	[ "$DRM_OPTION" = "drm-with-svp" ] && return 0 || return 1
}

function melon_ca_environment()
{
	PACKAGE=package5
	QA_SUPPLEMENT=${SCRIPTDIR}/qa_supplement/melon
	ANDROID_VENDOR_DIR=`android_vendor_dir_get`
	ANDROID_SYSTEM_DIR=`android_system_dir_get`
	mkdir -p ${ANDROID_VENDOR_DIR}/lib/teetz

	config_get KERNEL_TARGET_CHIP
	rsync -a ${QA_SUPPLEMENT}/${KERNEL_TARGET_CHIP}/vendor/lib/teetz/*.ta*      ${ANDROID_VENDOR_DIR}/lib/teetz/
}
