#!/bin/bash
[ "$ENV_DRM_SOURCE" != "" ] && return
ENV_DRM_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
source $SCRIPTDIR/env_qa_sub.sh
source $SCRIPTDIR/env_android.sh
source $SCRIPTDIR/env_vmx.sh

function drm_config()
{
    DRM_OPTION_LIST=
    list_add DRM_OPTION_LIST off
    list_add DRM_OPTION_LIST drm-without-svp
    list_add DRM_OPTION_LIST drm-with-svp
    config_get_menu DRM_OPTION DRM_OPTION_LIST off
}

function drm_type_is_off()
{
    config_get DRM_OPTION || drm_config
    [ "$DRM_OPTION" = "off" ] && return 0 || return 1
}

function drm_type_is_with_svp()
{
    config_get DRM_OPTION || drm_config
    [ "$DRM_OPTION" = "drm-with-svp" ] && return 0 || return 1
}

function drm_type_is_without_svp()
{
    config_get DRM_OPTION || drm_config
    [ "$DRM_OPTION" = "drm-without-svp" ] && return 0 || return 1
}

function drm_checkout()
{
    #if ! vmx_is_enable_ca_control; then
    if ! vmx_is_drm_enable; then
        drm_type_is_off && return 0
    fi
    qa_sub_checkout
    return $?
}

function drm_sync()
{
    #if ! vmx_is_enable_ca_control; then
    if ! vmx_is_drm_enable; then
        drm_type_is_off && return 0
    fi
    qa_sub_sync
    return $?
}

function drm_recent_libs()
{
    WV_LIB_PATH=`android_vendor_dir_get`/lib/
    TEE_WV_LIB_PATH=${WV_LIB_PATH}/mediadrm/

    #REMOVE_LIST=
    #list_add REMOVE_LIST ${WV_LIB_PATH}/liboemcrypto.so
    #list_add REMOVE_LIST ${TEE_WV_LIB_PATH}/libwvdrmengine.so
    #list_add REMOVE_LIST `android_system_dir_get`/lib/teetz
    #list_add REMOVE_LIST `android_system_dir_get`/bin/tee-supplicant

    LIBRARIES=
    list_add LIBRARIES liboemcrypto
    list_add LIBRARIES libwvdrmengine
    list_add LIBRARIES libPlayReadyDrmCryptoPlugin
    for l in $LIBRARIES
    do
        for f in .so .otp.enc .rsa
        do
            FILE=${TEE_WV_LIB_PATH}/${l}${f}
            list_add REMOVE_LIST $FILE
        done
    done

    for f in $REMOVE_LIST
    do
        [ -f "${f}" ] && rm -rf $f
    done
    return 0
}

function drm_setup_environment()
{
    drm_type_is_off && return 0

    config_get ANDROID_PRODUCT
    config_get KERNEL_TARGET_CHIP
    if [ "$KERNEL_TARGET_CHIP" = "kylin" ]; then
        DRM_TA_DIR=`qa_sub_dir_get`/widevine/kylin/
        TEE_DIR=`qa_sub_dir_get`/widevine/
        rsync -ac ${DRM_TA_DIR}/tee-supplicant    ${TEE_DIR}/system/bin/
        rsync -ac ${DRM_TA_DIR}/libteec.so        ${TEE_DIR}/system/lib/
        rsync -ac ${DRM_TA_DIR}/*.ta              ${TEE_DIR}/system/lib/teetz
        rsync -ac ${DRM_TA_DIR}/*.ta.enc          ${TEE_DIR}/system/lib/teetz
        rsync -ac ${DRM_TA_DIR}/tee_*             ${TEE_DIR}/system/bin/

    elif [ "$KERNEL_TARGET_CHIP" = "hercules" ]; then
        DRM_TA_DIR=`qa_sub_dir_get`/widevine/hercules/
        TEE_DIR=`qa_sub_dir_get`/widevine/
        SDK=`android_sdk_version_get`
        config_get IMAGE_DRAM_SIZE
        config_get ENABLE_VMX_DRM

        if [ "$SDK" == "9" ]; then
            rsync -ac ${DRM_TA_DIR}/wv_for_9.0/tee-supplicant ${TEE_DIR}/system/bin/
        else
            rsync -ac ${DRM_TA_DIR}/tee-supplicant    ${TEE_DIR}/system/bin/
        fi
        rsync -ac ${DRM_TA_DIR}/libteec.so        ${TEE_DIR}/system/lib/
        rsync -ac ${DRM_TA_DIR}/tee_*             ${TEE_DIR}/system/bin/
        rsync -ac ${DRM_TA_DIR}/*.ta              ${TEE_DIR}/system/lib/teetz

        if [ "$ANDROID_PRODUCT" == "RealtekSTB" ]; then
            rsync -ac ${DRM_TA_DIR}/wv_for_keybox_RealtekSTB/*.ta ${TEE_DIR}/system/lib/teetz
        fi

        if [ "`echo $IMAGE_DRAM_SIZE | grep "1GB.atv"`" != "" ]; then
            rsync -ac ${DRM_TA_DIR}/ATV_tee_api/*.ta     ${TEE_DIR}/system/lib/teetz
	elif [ "$ENABLE_VMX_DRM" == "true" ]; then
            rsync -ac ${DRM_TA_DIR}/VMX_tee_api/*.ta     ${TEE_DIR}/system/lib/teetz
        fi

     elif [ "$KERNEL_TARGET_CHIP" = "thor" ]; then
        DRM_TA_DIR=`qa_sub_dir_get`/widevine/thor/
        TEE_DIR=`qa_sub_dir_get`/widevine/
        SDK=`android_sdk_version_get`
        config_get  IMAGE_DRAM_SIZE

        if [ "$SDK" == "9" ]; then
            rsync -ac ${DRM_TA_DIR}/wv_for_9.0/tee-supplicant ${TEE_DIR}/system/bin/
        else
            rsync -ac ${DRM_TA_DIR}/tee-supplicant    ${TEE_DIR}/system/bin/
        fi
        rsync -ac ${DRM_TA_DIR}/libteec.so        ${TEE_DIR}/system/lib/
        rsync -ac ${DRM_TA_DIR}/tee_*             ${TEE_DIR}/system/bin/
        rsync -ac ${DRM_TA_DIR}/*.ta              ${TEE_DIR}/system/lib/teetz/

        if [ "$ANDROID_PRODUCT" == "RealtekSTB" ]; then
            rsync -ac ${DRM_TA_DIR}/wv_for_keybox_RealtekSTB/*.ta ${TEE_DIR}/system/lib/teetz
        fi
    else
        echo "Please check KERNEL_TARGET_CHIP: $KERNEL_TARGET_CHIP"
        return 0
    fi

    drm_recent_libs || return 1
    SDK=`android_sdk_version_get`
    if [ "$SDK" = "9" ]; then
        TEE_DIR=`qa_sub_dir_get`/widevine/system/
        ANDROID_VENDOR_DIR=`android_vendor_dir_get`
        DRM_TA_DIR=${TEE_DIR}/vendor/drm/9.0/
        if drm_type_is_with_svp ; then
            cp ${TEE_DIR}/vendor/lib/mediadrm/9.0/libwvdrmengine.so        ${ANDROID_VENDOR_DIR}/lib/mediadrm/
            cp ${TEE_DIR}/vendor/lib/9.0/liboemcrypto.so                   ${ANDROID_VENDOR_DIR}/lib/
            cp ${TEE_DIR}/vendor/lib/9.0/libwvhidl.so                      ${ANDROID_VENDOR_DIR}/lib/
            rsync -ac ${TEE_DIR}/bin/tee-supplicant                        ${ANDROID_VENDOR_DIR}/bin/
            rsync -ac ${TEE_DIR}/lib/libteec.so                            ${ANDROID_VENDOR_DIR}/lib/
            rsync -ac ${TEE_DIR}/bin/tee_*                                 ${ANDROID_VENDOR_DIR}/bin/
            rsync -ac ${TEE_DIR}/lib/teetz                                 ${ANDROID_VENDOR_DIR}/lib/
            cp ${DRM_TA_DIR}/android.hardware.drm@1.1-service.widevine     ${ANDROID_VENDOR_DIR}/bin/hw/
            cp ${DRM_TA_DIR}/android.hardware.drm@1.1-service.widevine.rc  ${ANDROID_VENDOR_DIR}/etc/init/
        elif drm_type_is_without_svp ; then
            cp ${TEE_DIR}/vendor/lib/mediadrm/9.0/libwvdrmengine.so        ${ANDROID_VENDOR_DIR}/lib/mediadrm/
            cp ${TEE_DIR}/vendor/lib/9.0/liboemcrypto.so                   ${ANDROID_VENDOR_DIR}/lib/
            cp ${TEE_DIR}/vendor/lib/9.0/libwvhidl.so                      ${ANDROID_VENDOR_DIR}/lib/
            rsync -ac ${TEE_DIR}/bin/tee-supplicant                        ${ANDROID_VENDOR_DIR}/bin/
            rsync -ac ${TEE_DIR}/lib/libteec.so                            ${ANDROID_VENDOR_DIR}/lib/
            rsync -ac ${TEE_DIR}/lib/teetz                                 ${ANDROID_VENDOR_DIR}/lib/
            cp ${DRM_TA_DIR}/android.hardware.drm@1.1-service.widevine     ${ANDROID_VENDOR_DIR}/bin/hw/
            cp ${DRM_TA_DIR}/android.hardware.drm@1.1-service.widevine.rc  ${ANDROID_VENDOR_DIR}/etc/init/
        else
            return 3
        fi
    elif [ "$SDK" = "8.1.0" ]; then
        TEE_DIR=`qa_sub_dir_get`/widevine/
        ANDROID_VENDOR_DIR=`android_vendor_dir_get`
        DRM_TA_DIR=`qa_sub_dir_get`/widevine/${KERNEL_TARGET_CHIP}/
        if drm_type_is_with_svp ; then
            cp ${TEE_DIR}/system/vendor/lib/mediadrm/8.1/libwvdrmengine.so ${ANDROID_VENDOR_DIR}/lib/mediadrm/
            cp ${TEE_DIR}/system/vendor/lib/8.1/liboemcrypto.so            ${ANDROID_VENDOR_DIR}/lib/
            cp ${TEE_DIR}/system/vendor/lib/mediadrm/8.1/libPlayReadyDrmCryptoPlugin.so ${ANDROID_VENDOR_DIR}/lib/mediadrm/
            rsync -ac ${TEE_DIR}/system/bin/tee-supplicant                 ${ANDROID_VENDOR_DIR}/bin/
            rsync -ac ${TEE_DIR}/system/lib/libteec.so                     ${ANDROID_VENDOR_DIR}/lib/
            rsync -ac ${TEE_DIR}/system/bin/tee_*                          ${ANDROID_VENDOR_DIR}/bin/
            rsync -ac ${TEE_DIR}/system/lib/teetz                          ${ANDROID_VENDOR_DIR}/lib/
            cp ${DRM_TA_DIR}/android.hardware.drm@1.0-service.widevine     ${ANDROID_VENDOR_DIR}/bin/hw/
            cp ${DRM_TA_DIR}/android.hardware.drm@1.0-service.widevine.rc  ${ANDROID_VENDOR_DIR}/etc/init/
            cp ${DRM_TA_DIR}/libwvhidl.so                                  ${ANDROID_VENDOR_DIR}/lib/
        elif drm_type_is_without_svp ; then
            cp ${TEE_DIR}/system/vendor/lib/mediadrm/8.1/libwvdrmengine.so ${ANDROID_VENDOR_DIR}/lib/mediadrm/
            cp ${TEE_DIR}/system/vendor/lib/8.1/liboemcrypto.so            ${ANDROID_VENDOR_DIR}/lib/
            rsync -ac ${TEE_DIR}/system/bin/tee-supplicant                 ${ANDROID_VENDOR_DIR}/bin/
            rsync -ac ${TEE_DIR}/system/lib/libteec.so                     ${ANDROID_VENDOR_DIR}/lib/
            rsync -ac ${TEE_DIR}/system/lib/teetz                          ${ANDROID_VENDOR_DIR}/lib/
            cp ${DRM_TA_DIR}/android.hardware.drm@1.0-service.widevine     ${ANDROID_VENDOR_DIR}/bin/hw/
            cp ${DRM_TA_DIR}/android.hardware.drm@1.0-service.widevine.rc  ${ANDROID_VENDOR_DIR}/etc/init/
            cp ${DRM_TA_DIR}/libwvhidl.so                                  ${ANDROID_VENDOR_DIR}/lib/
        else
            return 3
        fi
    elif [ "$SDK" = "8.0.0" ]; then
        TEE_DIR=`qa_sub_dir_get`/widevine/
        ANDROID_VENDOR_DIR=`android_vendor_dir_get`
        ANDROID_SYSTEM_DIR=`android_system_dir_get`

        if drm_type_is_with_svp ; then
            cp ${TEE_DIR}/system/vendor/lib/mediadrm/8.0/libwvdrmengine.so ${ANDROID_VENDOR_DIR}/lib/mediadrm/
            cp ${TEE_DIR}/system/vendor/lib/7.0/liboemcrypto.so            ${ANDROID_VENDOR_DIR}/lib/
            rsync -ac ${TEE_DIR}/system/bin/tee-supplicant                 ${ANDROID_VENDOR_DIR}/bin/
            rsync -ac ${TEE_DIR}/system/lib/libteec.so                     ${ANDROID_VENDOR_DIR}/lib/
            rsync -ac ${TEE_DIR}/system/bin/tee_*                          ${ANDROID_VENDOR_DIR}/bin/
            rsync -ac ${TEE_DIR}/system/lib/teetz                          ${ANDROID_VENDOR_DIR}/lib/
        elif drm_type_is_without_svp ; then
            cp ${TEE_DIR}/system/vendor/lib/mediadrm/8.0/libwvdrmengine.so ${ANDROID_VENDOR_DIR}/lib/mediadrm/
            cp ${TEE_DIR}/system/vendor/lib/7.0/liboemcrypto.so            ${ANDROID_VENDOR_DIR}/lib/
            rsync -ac ${TEE_DIR}/system/bin/tee-supplicant                 ${ANDROID_VENDOR_DIR}/bin/
            rsync -ac ${TEE_DIR}/system/lib/libteec.so                     ${ANDROID_VENDOR_DIR}/lib/
            rsync -ac ${TEE_DIR}/system/lib/teetz                          ${ANDROID_VENDOR_DIR}/lib/
        else
            return 3
        fi

    else
        TEE_DIR=`qa_sub_dir_get`/widevine/
        ANDROID_VENDOR_DIR=`android_vendor_dir_get`
        ANDROID_SYSTEM_DIR=`android_system_dir_get`

        if drm_type_is_with_svp ; then
            cp ${TEE_DIR}/system/vendor/lib/mediadrm/7.0/libwvdrmengine.so ${ANDROID_VENDOR_DIR}/lib/mediadrm/
            cp ${TEE_DIR}/system/vendor/lib/7.0/liboemcrypto.so            ${ANDROID_VENDOR_DIR}/lib/
            cp ${TEE_DIR}/system/vendor/lib/mediadrm/7.0/libPlayReadyDrmCryptoPlugin.so ${ANDROID_VENDOR_DIR}/lib/mediadrm/
            rsync -ac ${TEE_DIR}/system/bin/tee-supplicant                 ${ANDROID_SYSTEM_DIR}/bin/
            rsync -ac ${TEE_DIR}/system/lib/libteec.so                     ${ANDROID_SYSTEM_DIR}/lib/
            rsync -ac ${TEE_DIR}/system/bin/tee_*                          ${ANDROID_SYSTEM_DIR}/bin/
            rsync -ac ${TEE_DIR}/system/lib/teetz                          ${ANDROID_VENDOR_DIR}/lib/
        elif drm_type_is_without_svp ; then
            cp ${TEE_DIR}/system/vendor/lib/mediadrm/7.0/libwvdrmengine.so ${ANDROID_VENDOR_DIR}/lib/mediadrm/
            cp ${TEE_DIR}/system/vendor/lib/7.0/liboemcrypto.so            ${ANDROID_VENDOR_DIR}/lib/
            cp ${TEE_DIR}/system/vendor/lib/mediadrm/7.0/libPlayReadyDrmCryptoPlugin.so ${ANDROID_VENDOR_DIR}/lib/mediadrm/
            rsync -ac ${TEE_DIR}/system/bin/tee-supplicant                 ${ANDROID_SYSTEM_DIR}/bin/
            rsync -ac ${TEE_DIR}/system/lib/libteec.so                     ${ANDROID_SYSTEM_DIR}/lib/
            rsync -ac ${TEE_DIR}/system/lib/teetz                          ${ANDROID_VENDOR_DIR}/lib/
        else
            return 3
        fi
    fi

    return 0
}

function drm_clean_file_check()
{
    file_src=$1
    file_dst=$2
    [ ! -f "$file_src" ] && return 1
    [ ! -f "$file_dst" ] && return 0
    file_src_md5=`md5sum $file_src | awk '{print $1}'`
    file_dst_md5=`md5sum $file_dst | awk '{print $1}'`
    if [ "$file_src_md5" = "" ] || [ "$file_dst_md5" = "" ]; then
        echo "[ERROR] gapps_clean_file_check ($file_src) ($file_dst)"
        return 1
    fi
    [ "$file_src_md5" = "$file_dst_md5" ] && rm -rf $file_dst
    return 0;
}

export -f drm_clean_file_check

function drm_clean_environment_by_with_tee()
{
    TEE_DIR=`qa_sub_dir_get`/widevine/tee
    ANDROID_VENDOR_DIR=`android_vendor_dir_get`
    ANDROID_SYSTEM_DIR=`android_system_dir_get`
    if [ ! -d "$TEE_DIR" ] || [ ! -d "${ANDROID_VENDOR_DIR}" ] || [ ! -d "${ANDROID_SYSTEM_DIR}" ]; then
        echo drm_clean_environment_by_with_tee:
        echo TEE_DIR=$TEE_DIR
        echo ANDROID_VENDOR_DIR=$ANDROID_VENDOR_DIR
        echo ANDROID_SYSTEM_DIR=$ANDROID_SYSTEM_DIR
        return 0
    fi

    pushd ${TEE_DIR}/system > /dev/null
        find . -type f | xargs -i echo {} ${ANDROID_SYSTEM_DIR}/{}| xargs -i bash -c 'drm_clean_file_check {}'
    popd > /dev/null

    pushd ${TEE_DIR}/system/vendor > /dev/null
        find . -type f | xargs -i echo {} ${ANDROID_VENDOR_DIR}/{}| xargs -i bash -c 'drm_clean_file_check {}'
    popd > /dev/null

    return 0
}

function drm_clean_environment_by_wthout_tee()
{
    TEE_DIR=`qa_sub_dir_get`/widevine/wotee
    ANDROID_VENDOR_DIR=`android_vendor_dir_get`
    if [ ! -d "$TEE_DIR" ] || [ ! -d "${ANDROID_VENDOR_DIR}" ]; then
        echo drm_clean_environment_by_wthout_tee:
        echo TEE_DIR=$TEE_DIR
        echo ANDROID_VENDOR_DIR=$ANDROID_VENDOR_DIR
        return 0
    fi

    pushd ${TEE_DIR}/system/vendor > /dev/null
        find . -type f | xargs -i echo {} ${ANDROID_VENDOR_DIR}/{}| xargs -i bash -c 'drm_clean_file_check {}'
    popd > /dev/null
}

function drm_clean_environment()
{
    [ ! -d "`android_system_dir_get`" ] && return 0
    drm_type_is_off && [ ! -d "`qa_sub_dir_get`" ] && return 0

    if drm_type_is_off; then
        drm_clean_environment_by_with_tee
        drm_clean_environment_by_wthout_tee
    elif drm_type_is_with_svp; then
        drm_clean_environment_by_wthout_tee
    elif drm_type_is_without_svp; then
        drm_clean_environment_by_with_tee
    else
        return 1
    fi

    return 0
}
