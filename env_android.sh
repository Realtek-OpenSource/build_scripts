#!/bin/bash
[ "$ENV_ANDROID_SOURCE" != "" ] && return

ENV_ANDROID_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
source $SCRIPTDIR/env_hdcp.sh
source $SCRIPTDIR/env_secure_func.sh
source $SCRIPTDIR/env_drm.sh
source $SCRIPTDIR/env_gms.sh
source $SCRIPTDIR/env_tensorflow.sh
source $SCRIPTDIR/env_vmx.sh
source $SCRIPTDIR/env_xen.sh
source $SCRIPTDIR/env_kernel.sh
source $SCRIPTDIR/env_bootcode_lk.sh
source $SCRIPTDIR/env_ca.sh
source $SCRIPTDIR/env_image.sh
config_get GERRIT_MANIFEST
ANDROIDDIR=$TOPDIR/android
ANDROID_CONFIG_FILE=$TOPDIR/android/.build_config
BOOTCODE_LK_DIR=$TOPDIR/lk
PRODUCT_DEVICE_PATH=android/out/target/product/hercules32

function android_export_version_get()
{
    version=$BRANCH_QA_TARGET`date +"-%y%m%d-"`00
    [ "$1" != "" ] && export $1=${version} || echo ${version}
    return 0
}

function android_sdk_version_get()
{
    item=$1
    version=NULL

    ANDROID_CTS_VERSION_FILE=${ANDROIDDIR}/cts/tests/tests/os/assets/platform_versions.txt
    [ -e "${ANDROID_CTS_VERSION_FILE}" ] && version=`cat $ANDROID_CTS_VERSION_FILE`

    ANDROID_CORE_VERSION_DEFAULTS_FILE=${ANDROIDDIR}/build/core/version_defaults.mk
    if [ "$version" = "NULL" ] && [ -e "${ANDROID_CORE_VERSION_DEFAULTS_FILE}" ]; then
        version=`cat ${ANDROID_CORE_VERSION_DEFAULTS_FILE} |grep "^\ .PLATFORM_VERSION\ :="|awk '{print $3}'`
    fi

    [ "$item" != "" ] && export ${item}="${version}" || echo ${version}
    [ "$version" = "NULL" ] && return 1 || return 0
}

function android_dir_get()
{
    item=$1
    dir=$ANDROIDDIR
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function android_system_dir_get()
{
    android_env > /dev/null 2>&1
    item=$1
    dir=`android_product_out_dir_get`/system
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function android_misc_bin_get()
{
    android_env > /dev/null 2>&1
    item=$1
    dir=`android_product_out_dir_get`/misc.bin
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function android_system_other_dir_get()
{
    android_env > /dev/null 2>&1
    item=$1
    dir=`android_product_out_dir_get`/system_other
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function android_root_dir_get()
{
    android_env > /dev/null 2>&1
    item=$1
    dir=`android_product_out_dir_get`/root
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function android_vendor_dir_get()
{
    android_env > /dev/null 2>&1
    item=$1
    dir=`android_product_out_dir_get`/vendor
    [ ! -d "$dir" ] && dir=`android_product_out_dir_get`/system/vendor
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function android_product_out_dir_get()
{
    android_env > /dev/null 2>&1
    item=$1
    dir=$ANDROID_PRODUCT_OUT
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function android_build_type_get()
{
    android_env > /dev/null 2>&1
    item=$1
    build_type=$ANDROID_BUILDTYPE
    [ "$item" != "" ] && export ${item}="${build_type}" || echo ${build_type}
    return 0
}

function android_config_check_version()
{
    case "$BRANCH_PARENT" in
        phoenix-ll-5.0.0-b)
            config_get ANDROID_CODENAME
            if [ "$?" != "0" ] || [ "$ANDROID_CODENAME" != "lollipop" ]; then
                config_set ANDROID_CODENAME lollipop
            fi
            ;;
        phoenix-kk-4.4.4_r1-b | phoenix-kk-mr0-b)
            config_get ANDROID_CODENAME
            if [ "$?" != "0" ] || [ "$ANDROID_CODENAME" != "kitkat" ]; then
                config_set ANDROID_CODENAME kitkat
            fi
            ;;
        android-7.0.0-b)
            config_get ANDROID_CODENAME
            if [ "$?" != "0" ] || [ "$ANDROID_CODENAME" != "nougat" ]; then
                config_set ANDROID_CODENAME nougat
            fi
            ;;
    esac
}

# configure before android source is checked out
function android_config()
{
    ANDROID_PRODUCT_LIST=
    list_add ANDROID_PRODUCT_LIST "=====Android_KK===="
    list_add ANDROID_PRODUCT_LIST rtk_phoenix
    list_add ANDROID_PRODUCT_LIST rtk_phoenix_lm
    list_add ANDROID_PRODUCT_LIST rtk_kylin
    list_add ANDROID_PRODUCT_LIST rtk_hercules
    list_add ANDROID_PRODUCT_LIST "=====Android_L,M,N===="
    list_add ANDROID_PRODUCT_LIST rtk_kylin32
    list_add ANDROID_PRODUCT_LIST rtk_kylin32_tv
    list_add ANDROID_PRODUCT_LIST rtk_kylin64
    list_add ANDROID_PRODUCT_LIST rtk_kylin64_tv
    list_add ANDROID_PRODUCT_LIST rtk_kylin32_mini
    list_add ANDROID_PRODUCT_LIST rtk_kylin64_mini
    list_add ANDROID_PRODUCT_LIST rtk_hercules32
    list_add ANDROID_PRODUCT_LIST rtk_hercules32_tv
    list_add ANDROID_PRODUCT_LIST rtk_hercules64
    list_add ANDROID_PRODUCT_LIST rtk_hercules64_tv
    list_add ANDROID_PRODUCT_LIST rtk_hercules32_mini
    list_add ANDROID_PRODUCT_LIST rtk_hercules32_mini2
    list_add ANDROID_PRODUCT_LIST "=====Android_O,P===="
    list_add ANDROID_PRODUCT_LIST rtk_kylin32
    list_add ANDROID_PRODUCT_LIST rtk_kylin32_tv
    list_add ANDROID_PRODUCT_LIST hercules32
    list_add ANDROID_PRODUCT_LIST hercules32tv
    list_add ANDROID_PRODUCT_LIST hercules64
    list_add ANDROID_PRODUCT_LIST hercules64tv
    list_add ANDROID_PRODUCT_LIST hercules32mini
    list_add ANDROID_PRODUCT_LIST thor32
    list_add ANDROID_PRODUCT_LIST thor32tv
    list_add ANDROID_PRODUCT_LIST thor64
    list_add ANDROID_PRODUCT_LIST thor64tv
    list_add ANDROID_PRODUCT_LIST atv1gb
    list_add ANDROID_PRODUCT_LIST RealtekSTB
    list_add ANDROID_PRODUCT_LIST RealtekATV
    list_add ANDROID_PRODUCT_LIST thor32mini
    list_add ANDROID_PRODUCT_LIST thor32mini2

    ANDROID_VARIANT_LIST=
    list_add ANDROID_VARIANT_LIST eng
    list_add ANDROID_VARIANT_LIST user
    list_add ANDROID_VARIANT_LIST userdebug

    config_get ANDROID_BUILDTYPE
    if [ "$?" == "0" ]; then
        ANDROID_PRODUCT_MAIN=`echo $ANDROID_BUILDTYPE | awk -F- '{print $1}'`
        ANDROID_VARIANT_MAIN=`echo $ANDROID_BUILDTYPE | awk -F- '{print $2}'`

        config_get ANDROID_PRODUCT
        if [ "$?" != "0" ] || [ "$ANDROID_PRODUCT" != "$ANDROID_PRODUCT_MAIN" ]; then
            config_set ANDROID_PRODUCT $ANDROID_PRODUCT_MAIN
        fi

        config_get ANDROID_VARIANT
        if [ "$?" != "0" ] || [ "$ANDROID_VARIANT" != "$ANDROID_VARIANT_MAIN" ]; then
            config_set ANDROID_VARIANT $ANDROID_VARIANT_MAIN
        fi
    else
        config_get_menu ANDROID_PRODUCT ANDROID_PRODUCT_LIST rtk_phoenix
        config_get_menu ANDROID_VARIANT ANDROID_VARIANT_LIST eng

        config_get ANDROID_BUILDTYPE
        if [ "$?" != "0" ] || [ "$ANDROID_BUILDTYPE" != "$ANDROID_PRODUCT-$ANDROID_VARIANT" ]; then
            config_set ANDROID_BUILDTYPE $ANDROID_PRODUCT-$ANDROID_VARIANT
        fi
    fi

    config_get_bool ANDROID_CA_PLAYER_EN    false
    config_get_bool ANDROID_CLEAR_ROOT      false
    config_get_bool ANDROID_CLEAR_SYSTEM    false
    config_get_bool ANDROID_CLEAR_VERDOR    false
    vmx_config
    android_config_check_version

    hdcp_config
	secure_func_config
    drm_config
    #gms_config
    #tf_config
    #xen_config
    image_dram_size_config
    return 0
}

function android_is_use_ca_player()
{
    config_get ANDROID_CA_PLAYER_EN
    [ "$ANDROID_CA_PLAYER_EN" = "true" ] && return 0 || return 1
}

function android_init()
{
    [ ! -d "$ANDROIDDIR" ] && mkdir $ANDROIDDIR
    pushd $ANDROIDDIR > /dev/null
    case "$BRANCH_QA_TARGET" in
        trunk-6.0.0_r1-b/kernel-4.1.7_RTD1295_WD_NAS-20160730)
            ANDROID_MANIFEST_BRANCH=phoenix-mm-6.0.0-b/WDBranch-20161014
            ;;
        *)
            ANDROID_MANIFEST_BRANCH=$BRANCH_PARENT/$BRANCH_QA_TARGET
            ;;
    esac
    config_get GERRIT_MANIFEST
#    repo init -u $GERRIT_MANIFEST -b $ANDROID_MANIFEST_BRANCH -m android.xml $REPO_PARA
    repo init -u $GERRIT_MANIFEST -b master -m android.xml $REPO_PARA
    popd > /dev/null
    #gms_init    || return 1
    return 0
}

function android_sync()
{
    drm_sync    || return 2
    #gms_sync    || return 3
    #tf_sync     || return 4
    ret=1
    [ ! -d "$ANDROIDDIR" ] && return 0
    pushd $ANDROIDDIR > /dev/null
        repo sync -j $MULTI --force-sync
        ret=$?
        [ "$ret" = "0" ] && > .repo_ready
    popd > /dev/null
    return $ret
}

function android_checkout()
{
    drm_checkout    || return 2
    #gms_checkout    || return 3
    #tf_checkout     || return 4
    [ -e "$ANDROIDDIR/.repo_ready" ] && return 0
    android_init && android_sync && (> $ANDROIDDIR/.repo_ready) || return 2
    return $?
}

function android_env()
{
    config_get ANDROID_BUILDTYPE || return 1
    [ ! -d "$ANDROIDDIR" ] && return 2
    [ "$ANDROID_BUILDTYPE" = "${TARGET_PRODUCT}-${TARGET_BUILD_VARIANT}" ] && return 0
    pushd $ANDROIDDIR > /dev/null
    source ./env.sh || return $?
    lunch $ANDROID_BUILDTYPE || return $?
    popd > /dev/null
    return 0
}

function android_is_low_ram()
{
    [ "`image_dram_size_MB_get`" -le "1024" ] && return 0 || return 1
}

function android_export_environmental_variables()
{
    hdcp_tx_1px_en          && export USE_RTK_HDCP1x_CONTROL=YES        || export USE_RTK_HDCP1x_CONTROL=NO
    hdcp_tx_2p2_en          && export USE_RTK_HDCP22_CONTROL=YES        || export USE_RTK_HDCP22_CONTROL=NO
    hdcp_tx_tee_en          && export USE_RTK_HDCP_TEE=YES              || export USE_RTK_HDCP_TEE=NO
    hdcp_rx_1px_en          && export USE_RTK_HDCPRX1x_CONTROL=YES      || export USE_RTK_HDCPRX1x_CONTROL=NO
    hdcp_rx_2p2_en          && export USE_RTK_HDCPRX22_CONTROL=YES      || export USE_RTK_HDCPRX22_CONTROL=NO
    hdcp_rx_tee_en          && export USE_RTK_HDCPRX_TEE=YES            || export USE_RTK_HDCPRX_TEE=NO
    drm_type_is_with_svp    && export ENABLE_TEE_DRM_FLOW=true          || export ENABLE_TEE_DRM_FLOW=false
    secure_func_dmverity_is_enable      && export DMVERITY_ENABLE=YES               || export DMVERITY_ENABLE=NO
    secure_func_dtb_enc_is_enable       && export DTB_ENC=true                      || export DTB_ENC=false
    image_tee_fw_is_enable              && export TEE_FW=true                       || export TEE_FW=false
    vmx_is_use_rtk_extractor    && export USE_VMX_RTK_EXTRACTOR_CONTROL=true    || export USE_VMX_RTK_EXTRACTOR_CONTROL=false
    vmx_is_use_vmx_apk          && export USE_VMX_DEMO_APK=true                 || export USE_VMX_DEMO_APK=false
    #vmx_is_enable_ca_control               && export ENABLE_VMX_CA_CONTROL=YES                   || export ENABLE_VMX_CA_CONTROL=NO
    vmx_is_enable_boot_flow                && export ENABLE_VMX_BOOT_FLOW=YES                    || export ENABLE_VMX_BOOT_FLOW=NO
	vmx_is_iptv_client			&& export USE_VMX_IPTV_CLIENT=YES				|| export USE_VMX_IPTV_CLIENT=NO
	vmx_is_dvb_client			&& export USE_VMX_DVB_CLIENT=YES				|| export USE_VMX_DVB_CLIENT=NO
	vmx_is_web_client			&& export USE_VMX_WEB_CLIENT=YES				|| export USE_VMX_WEB_CLIENT=NO
        vmx_is_enable_ultra                     && export ENABLE_VMX_ULTRA=YES                                  || export ENABLE_VMX_ULTRA=NO
	vmx_is_drm_enable			&& export ENABLE_VMX_DRM=YES            		|| export ENABLE_VMX_DRM=NO
	image_enable_ab_system      && export ENABLE_AB_SYSTEM=YES				|| export ENABLE_AB_SYSTEM=NO
	android_is_use_ca_player    && export USE_CA_PLAYER=YES 				|| export USE_CA_PLAYER=NO
	android_is_use_ca_player    && export ENABLE_CUST_MOD=YES 				|| export ENABLE_CUST_MOD=NO
    xen_is_enable          && export XEN_IS_ENABLE=YES        || export XEN_IS_ENABLE=NO
    ca_is_nocs_enable        && export ENABLE_NOCS=YES 				|| export ENABLE_NOCS=NO
    android_is_low_ram          && export ENABLE_LOW_RAM=true 			    || export ENABLE_LOW_RAM=false
    
	store_list=
        list_add store_list USE_RTK_HDCP1x_CONTROL
        list_add store_list USE_RTK_HDCP22_CONTROL
        list_add store_list USE_RTK_HDCP_TEE
        list_add store_list USE_RTK_HDCPRX1x_CONTROL
        list_add store_list USE_RTK_HDCPRX22_CONTROL
        list_add store_list USE_RTK_HDCPRX_TEE
        list_add store_list ENABLE_TEE_DRM_FLOW
        list_add store_list DMVERITY_ENABLE
        list_add store_list DTB_ENC
        list_add store_list TEE_FW
        list_add store_list USE_VMX_RTK_EXTRACTOR_CONTROL
        list_add store_list USE_VMX_DEMO_APK
        #list_add store_list ENABLE_VMX_CA_CONTROL
        list_add store_list ENABLE_VMX_BOOT_FLOW
        list_add store_list USE_VMX_IPTV_CLIENT
        list_add store_list USE_VMX_DVB_CLIENT
        list_add store_list USE_VMX_WEB_CLIENT
        list_add store_list ENABLE_VMX_ULTRA
        list_add store_list ENABLE_VMX_DRM
	list_add store_list ENABLE_AB_SYSTEM
		list_add store_list USE_CA_PLAYER
		list_add store_list ENABLE_CUST_MOD
		list_add store_list XEN_IS_ENABLE
        list_add store_list ENABLE_NOCS
        list_add store_list ENABLE_LOW_RAM

    for i in $store_list
    do
        store_item=$i
        android_config_set $store_item ${!store_item}
    done
}

function android_auto_clear()
{
    clear_list=
    config_get_true ANDROID_CLEAR_ROOT      && list_add clear_list `android_root_dir_get`
    config_get_true ANDROID_CLEAR_SYSTEM    && list_add clear_list `android_system_dir_get`
    config_get_true ANDROID_CLEAR_VERDOR    && list_add clear_list `android_vendor_dir_get`
    config_get_true ANDROID_CLEAR_SYSTEM    && list_add clear_list `android_product_out_dir_get`/obj/ETC/system_build_prop_intermediates
    for f in $clear_list
    do
        if [ -e "$f" ]; then
            echo rm -rf $f
            rm -rf $f
        fi
    done
}

function prepare_modules()
{
    ANDROID_VERSION=`get_android_major_version`
    if [ $ANDROID_VERSION -ge 9 ]; then
        config_get IMAGE_TARGET_CHIP
        MODPATH=$ANDROIDDIR/device/realtek/$IMAGE_TARGET_CHIP/common/prebuilt/modules
        echo copy kernel modules to $MODPATH
        rsync -acP --copy-links `kernel_external_modules_list_get` $MODPATH
    fi
    return 0
}

function android_build()
{
    [ ! -e "$ANDROIDDIR/.repo_ready" ] && build_cmd android_checkout
    config_get VMX_TYPE
    config_get IMAGE_TARGET_CHIP
    config_get ANDROID_PRODUCT
    android_export_environmental_variables
    build_cmd android_env
    build_cmd prepare_modules
    drm_clean_environment   || return 2
    #gms_setup_environment   || return 3
    android_auto_clear
    ANDROID_VERSION=`get_android_major_version`
    pushd $ANDROIDDIR
        #make -j $MULTI -l $LOAD_AVERAGE $VERBOSE
        make -j $MULTI $VERBOSE || return 4
        #make recoveryimage for auto build rescue rootfs
        if [ $ANDROID_VERSION -ge 9 ]; then
            if [ ! -e out/target/product/$ANDROID_PRODUCT/recovery.img ]; then
                sed -i "s/TARGET_NO_RECOVERY := true/TARGET_NO_RECOVERY := false/g" device/realtek/$IMAGE_TARGET_CHIP/common/BoardConfigCommon.mk
                make recoveryimage || return 5
                sed -i "s/TARGET_NO_RECOVERY := false/TARGET_NO_RECOVERY := true/g" device/realtek/$IMAGE_TARGET_CHIP/common/BoardConfigCommon.mk
            fi
        elif [ $ANDROID_VERSION -eq 4 ]; then
            if [ ! -e out/target/product/$ANDROID_PRODUCT/recovery.img ]; then
                sed -i "s/TARGET_NO_RECOVERY := true/TARGET_NO_RECOVERY := false/g" device/realtek/$IMAGE_TARGET_CHIP/BoardConfig.mk
                sed -i "s/TARGET_NO_KERNEL := true/TARGET_NO_KERNEL := false/g" device/realtek/$IMAGE_TARGET_CHIP/BoardConfig.mk
                make recoveryimage || return 5
                sed -i "s/TARGET_NO_RECOVERY := false/TARGET_NO_RECOVERY := true/g" device/realtek/$IMAGE_TARGET_CHIP/BoardConfig.mk
                sed -i "s/TARGET_NO_KERNEL := false/TARGET_NO_KERNEL := true/g" device/realtek/$IMAGE_TARGET_CHIP/BoardConfig.mk
            fi
        fi
        ERR=$?
    popd
    return $ERR
}

function android_clean()
{
    local android_build_out=${ANDROIDDIR}/out
    [ -d "$android_build_out" ] && rm -rf $android_build_out
}

function android_build_otapackage()
{
    android_export_environmental_variables
    build_cmd android_env
    pushd $ANDROIDDIR
        make otapackage
        ERR=$?
    popd
    return $ERR
}

function android_update_api()
{
    [ ! -d "$ANDROIDDIR" ] && return 1
    android_export_environmental_variables
    pushd $ANDROIDDIR
        #make -j $MULTI -l $LOAD_AVERAGE $VERBOSE update-api
        make -j $MULTI $VERBOSE update-api
        ERR=$?
    popd
    return $ERR
}

function android_type_is_64()
{
    config_get ANDROID_BUILDTYPE || android_config
    [[ $ANDROID_BUILDTYPE ==  *"64"* ]] && return 0 || return 1
}


function android_type_is_32()
{
    android_type_is_64 && return 1 || return 0
}

function android_config_set()
{
    old_config_file=${CONFIG_FILE}
    CONFIG_FILE=$ANDROID_CONFIG_FILE
    config_set $1 $2
    CONFIG_FILE=${old_config_file}
}

function ln_libOMX_realtek()
{

#echo"start copy ext_img"
#cd $PRODUCT_DEVICE_PATH/

echo "PRODUCT_DEVICE_PATH" $PRODUCT_DEVICE_PATH
cp android/ext_vendor/* $PRODUCT_DEVICE_PATH/vendor/lib/.
cp android/ext_system/* $PRODUCT_DEVICE_PATH/system/lib/.
cd $PRODUCT_DEVICE_PATH/vendor/lib/
        echo "Starting force link OMX libraries"

ln -sf libOMX.realtek.audio.dec.so libOMX.realtek.audio.dec.secure.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.3gpp.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.avc.secure.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.avc.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.avs.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.divx3.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.flv.so
ln -sf libOMX.realtek.video.so libOMX.realtek.video.dec.hevc.secure.so
ln -sf libOMX.realtek.video.so libOMX.realtek.video.dec.hevc.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.mjpg.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.mpeg2.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.mpeg4.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.raw.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.rv30.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.rv40.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.rv.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.vc1.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.vp8.so
ln -sf libOMX.realtek.video.so libOMX.realtek.video.dec.vp9.secure.so
ln -sf libOMX.realtek.video.so libOMX.realtek.video.dec.vp9.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.wmv3.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.wmv.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.wvc1.so
ln -sf libOMX.realtek.video.enc.so libOMX.realtek.video.enc.avc.so
ln -sf libOMX.realtek.video.enc.so libOMX.realtek.video.enc.mpeg4.so
}
