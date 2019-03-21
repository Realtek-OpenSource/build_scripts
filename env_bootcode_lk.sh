#!/bin/bash

[ "$ENV_BOOTCODE_LK_SOURCE" != "" ] && return
ENV_BOOTCODE_LK_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
source $SCRIPTDIR/env_image.sh
source $SCRIPTDIR/env_image_secure.sh
source $SCRIPTDIR/env_drm.sh
source $SCRIPTDIR/env_vmx.sh

BOOTCODE_LK_DIR=$TOPDIR/lk
LK_FLASH_WRITER_NV_FOLDER=flash_writer_nv
LK_FLASH_WRITER_FOLDER=flash_writer
LK_FLASH_WRITER_VM_FOLDER=flash_writer_vm

function bootcode_lk_dir_get()
{
    bootcode_lk_item=$1
    dir=$BOOTCODE_LK_DIR
    [ "$bootcode_lk_item" != "" ] && export ${bootcode_lk_item}="${dir}" || echo ${dir}
    return 0
}

function bootcode_lk_bootloader_tar_get()
{
    bootcode_lk_item=$1
    file=$BOOTCODE_LK_DIR/bootloader_lk.tar
    [ "$bootcode_lk_item" != "" ] && export ${bootcode_lk_item}="${file}" || echo ${file}
    return 0
}

function bootcode_lk_lk_bin_get()
{
    bootcode_lk_item=$1
    file=$BOOTCODE_LK_DIR/build-${BOOTCODE_LK_CHIP_ID}/lk.bin
    [ "$bootcode_lk_item" != "" ] && export ${bootcode_lk_item}="${file}" || echo ${file}
    return 0
}

function bootcode_lk_tools_efuse_verify_out_dir_get()
{
    bootcode_lk_item=$1
    dir=$BOOTCODE_LK_DIR/tools/efuse_verify/out
    [ "$bootcode_lk_item" != "" ] && export ${bootcode_lk_item}="${dir}" || echo ${dir}
    return 0
}

function bootcode_lk_key_dir_get()
{
    bootcode_lk_item=$1

    config_get VMX_TYPE

    if vmx_is_enable_boot_flow; then
        if [ ${VMX_TYPE} == "ultra" ]; then
            dir=$BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_VM_FOLDER/image/vm_ultra
        else
            dir=$BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/image/vm_advance
        fi
    else
        if [ "$IMAGE_TARGET_CHIP" == "thor" ]; then
            dir=$BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_NV_FOLDER/image
        else
            dir=$BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/image
        fi
    fi

    [ "$bootcode_lk_item" != "" ] && export ${bootcode_lk_item}="${dir}" || echo ${dir}
    return 0
}

function bootcode_lk_init()
{
    bootcode_lk_type_is_off && return 0
    [ ! -d "$BOOTCODE_LK_DIR" ] && mkdir $BOOTCODE_LK_DIR
    pushd $BOOTCODE_LK_DIR > /dev/null
    repo init -u $GERRIT_MANIFEST -b $BRANCH_PARENT/$BRANCH_QA_TARGET -m bootcode_lk.xml $REPO_PARA
    ERR=$?
    popd > /dev/null
    return $ERR;
}

function bootcode_lk_sync()
{
    bootcode_lk_type_is_off && return 0
    ERR=0
    if [ -d "$BOOTCODE_LK_DIR" ]; then
        pushd $BOOTCODE_LK_DIR > /dev/null
        repo sync --force-sync
        ERR=$?
        popd > /dev/null
    else
        ERR=1
    fi
    return $ERR
}

function bootcode_lk_create_start_branch()
{
    pushd `bootcode_lk_dir_get` > /dev/null
        repo start local_`date +%Y_%m_%d_%H%M` --all
    popd > /dev/null
}

function bootcode_lk_checkout()
{
    bootcode_lk_type_is_off && return 0
    ERR=0
    if [ ! -e "${BOOTCODE_LK_DIR}/.repo_ready" ]; then
        bootcode_lk_init && bootcode_lk_sync && (> ${BOOTCODE_LK_DIR}/.repo_ready) || ERR=1
        [ "$ERR" = "0" ] && bootcode_lk_create_start_branch
    fi
    return $ERR
}

function bootcode_lk_type_is_off()
{
    config_get BOOTCODE_LK_OPTION || bootcode_lk_config
    [ "$BOOTCODE_LK_OPTION" = "off" ] && return 0 || return 1
}

function bootcode_lk_config()
{
    BOOTCODE_LK_OPTION_LIST=
    list_add BOOTCODE_LK_OPTION_LIST on
    list_add BOOTCODE_LK_OPTION_LIST off
    config_get_menu BOOTCODE_LK_OPTION BOOTCODE_LK_OPTION_LIST off

    if [ "$BOOTCODE_LK_OPTION" = "on" ]; then
        bootcode_lk_checkout || return 1
        BOOTCODE_LK_CHIP_ID_LIST=`bootcode_lk_chip_id_list_get`
        config_get_menu BOOTCODE_LK_CHIP_ID BOOTCODE_LK_CHIP_ID_LIST `echo $BOOTCODE_LK_CHIP_ID_LIST | awk '{print $1}'`
		if [ "$BOOTCODE_LK_CHIP_ID" == "rtd1395" ] || [ "$BOOTCODE_LK_CHIP_ID" == "rtd1355" ]; then
			LK_FLASH_WRITER_FOLDER=flash_writer_vm
		fi
        BOOTCODE_LK_CUSTOMER_ID_LIST=`bootcode_lk_customer_id_list_get`
        config_get_menu BOOTCODE_LK_CUSTOMER_ID BOOTCODE_LK_CUSTOMER_ID_LIST `echo $BOOTCODE_LK_CUSTOMER_ID_LIST|awk '{print $1}'`
        BOOTCODE_LK_CHIP_VERSION_LIST=`bootcode_lk_chip_version_list_get`
        config_get_menu BOOTCODE_LK_CHIP_VERSION BOOTCODE_LK_CHIP_VERSION_LIST `echo $BOOTCODE_LK_CHIP_VERSION_LIST| awk '{print $1}'`
        BOOTCODE_LK_HWSETTING_LIST=`bootcode_lk_hwsetting_list_get`
        config_get_menu BOOTCODE_LK_HWSETTING BOOTCODE_LK_HWSETTING_LIST `echo $BOOTCODE_LK_HWSETTING_LIST | awk '{print $1}'`
        BOOTCODE_LK_PRJ_LIST=`bootcode_lk_prj_list_get`
        config_get_menu BOOTCODE_LK_PRJ BOOTCODE_LK_PRJ_LIST `echo $BOOTCODE_LK_PRJ_LIST | awk '{print $1}'`
		
		BOOTCODE_SECURE_TYPE=
		list_add BOOTCODE_SECURE_TYPE 0
		list_add BOOTCODE_SECURE_TYPE 1
		config_get_menu LK_FW_LOAD BOOTCODE_SECURE_TYPE 1
		
		BOOTCODE_DRM_OPTION=
		list_add BOOTCODE_DRM_OPTION off
		list_add BOOTCODE_DRM_OPTION on
		config_get_menu DRM_TYPE BOOTCODE_DRM_OPTION off
		if 	[ "$BOOTCODE_LK_CHIP_ID" == "rtd1395" ]; then
            LK_FLASH_WRITER_FOLDER=flash_writer_vm
			if [ "$DRM_TYPE" = "off" ]; then
				cp $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/image/tee_os/$BOOTCODE_LK_CHIP_VERSION/fsbl-os-00.00.bin.bypass.enc $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/bootimage/$BOOTCODE_LK_CHIP_ID/$BOOTCODE_LK_CHIP_VERSION/fsbl-os-00.00.bin.enc
			else
				cp $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/image/tee_os/$BOOTCODE_LK_CHIP_VERSION/fsbl-os-00.00.bin.drm.enc $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/bootimage/$BOOTCODE_LK_CHIP_ID/$BOOTCODE_LK_CHIP_VERSION/fsbl-os-00.00.bin.enc
			fi
		else
			if [ "$DRM_TYPE" = "off" ]; then
				cp $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/image/tee_os/fsbl-os-00.00.bin.slim $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/bootimage/$BOOTCODE_LK_CHIP_ID/fsbl-os-00.00.bin
			else
				cp $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/image/tee_os/fsbl-os-00.00.bin.enlarge $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/bootimage/$BOOTCODE_LK_CHIP_ID/fsbl-os-00.00.bin
			fi
		fi
    else
        config_remove BOOTCODE_LK_CHIP_ID
        config_remove BOOTCODE_LK_CUSTOMER_ID
        config_remove BOOTCODE_LK_CHIP_VERSION
        config_remove BOOTCODE_LK_HWSETTING
        config_remove BOOTCODE_LK_PRJ
		config_remove LK_FW_LOAD
		config_remove DRM_TYPE
    fi

    image_secure_config
}

function bootcode_lk_chip_id_list_get()
{
    lk_item=$1
    hw_setting_dir=`bootcode_lk_dir_get`/tools/flash_writer/image/hw_setting
    if [ ! -d "$hw_setting_dir" ]; then
        echo "ERROR! $hw_setting_dir not found!"
        return 1
    fi

    pushd $hw_setting_dir > /dev/null
    BOOTCODE_LK_CHIP_ID_LIST=`ls | grep -v ".*.bin"`
    popd > /dev/null
	
	hw_setting_dir=`bootcode_lk_dir_get`/tools/flash_writer_vm/image/hw_setting
    if [ ! -d "$hw_setting_dir" ]; then
        echo "ERROR! $hw_setting_dir not found!"
        return 1
    fi
	
	BOOTCODE_LK_CHIP_ID_LIST+=' '
	pushd $hw_setting_dir > /dev/null
    BOOTCODE_LK_CHIP_ID_LIST+=`ls | grep -v ".*.bin"`
    popd > /dev/null

    [ "$lk_item" != "" ] && export ${lk_item}="${BOOTCODE_LK_CHIP_ID_LIST}" || echo "${BOOTCODE_LK_CHIP_ID_LIST}"
    return 0
}

function bootcode_lk_customer_id_list_get()
{
    lk_item=$1
    config_get BOOTCODE_LK_CHIP_ID

    if [ "$BOOTCODE_LK_CHIP_ID" = "" ] ; then
        echo "ERROR! BOOTCODE_LK_CHIP_ID($BOOTCODE_LK_CHIP_ID) not found"
        return 1
    fi

    hw_setting_customer_dir=`bootcode_lk_dir_get`/tools/$LK_FLASH_WRITER_FOLDER/image/hw_setting/${BOOTCODE_LK_CHIP_ID}

    if [ ! -d "$hw_setting_customer_dir" ]; then
        echo "ERROR! $hw_setting_customer_dir not found!"
        return 1
    fi

    pushd $hw_setting_customer_dir > /dev/null
    BOOTCODE_LK_CUSTOMER_ID_LIST=`ls`
    popd > /dev/null

    [ "$lk_item" != "" ] && export ${lk_item}="${BOOTCODE_LK_CUSTOMER_ID_LIST}" || echo "${BOOTCODE_LK_CUSTOMER_ID_LIST}"
    return 0
}

function bootcode_lk_chip_version_list_get()
{
    ERR=0
    lk_item=$1
    config_get BOOTCODE_LK_CHIP_ID || ERR=1
    config_get BOOTCODE_LK_CUSTOMER_ID || ERR=1

    if [ "$ERR" != 0 ]; then
        echo "ERROR! bootcode_lk_chip_version_list_get!"
        return 1
    fi

    hw_setting_customer_version_dir=`bootcode_lk_dir_get`/tools/$LK_FLASH_WRITER_FOLDER/image/hw_setting/${BOOTCODE_LK_CHIP_ID}/${BOOTCODE_LK_CUSTOMER_ID}

    if [ ! -d "$hw_setting_customer_version_dir" ]; then
        echo "ERROR! $hw_setting_customer_version_dir not found!"
        return 1
    fi

    pushd $hw_setting_customer_version_dir > /dev/null
    BOOTCODE_LK_CHIP_VERSION_LIST=`ls`
    popd > /dev/null

    [ "$lk_item" != "" ] && export ${lk_item}="${BOOTCODE_LK_CHIP_VERSION_LIST}" || echo "${BOOTCODE_LK_CHIP_VERSION_LIST}"
    return 0
}

function bootcode_lk_hwsetting_list_get()
{
    ERR=0
    lk_item=$1
    config_get BOOTCODE_LK_CHIP_ID || ERR=1
    config_get BOOTCODE_LK_CUSTOMER_ID || ERR=1
    config_get BOOTCODE_LK_CHIP_VERSION || ERR=1

    if [ "$ERR" != 0 ]; then
        echo "ERROR! bootcode_lk_hwsetting_list_get!"
        return 1
    fi

    hw_setting_target_dir=`bootcode_lk_dir_get`/tools/$LK_FLASH_WRITER_FOLDER/image/hw_setting/${BOOTCODE_LK_CHIP_ID}/${BOOTCODE_LK_CUSTOMER_ID}/${BOOTCODE_LK_CHIP_VERSION}

    if [ ! -d "$hw_setting_target_dir" ]; then
        echo "ERROR! $hw_setting_target_dir not found!"
        return 1
    fi

    pushd $hw_setting_target_dir > /dev/null
    BOOTCODE_LK_HWSETTING_LIST=`ls | cut -d '.' -f 1`
    popd > /dev/null

    [ "$lk_item" != "" ] && export ${lk_item}="${BOOTCODE_LK_HWSETTING_LIST}" || echo "${BOOTCODE_LK_HWSETTING_LIST}"
    return 0
}

function bootcode_lk_prj_list_get()
{
    lk_item=$1
    lk_prj_dir=`bootcode_lk_dir_get`/tools/$LK_FLASH_WRITER_FOLDER/inc

    if [ ! -d "$lk_prj_dir" ]; then
        echo "ERROR! $lk_prj_dir not found!"
        return 1
    fi

    pushd $lk_prj_dir > /dev/null
    BOOTCODE_LK_PRJ_LIST=`ls | cut -d '.' -f 1`
    popd > /dev/null

    [ "$lk_item" != "" ] && export ${lk_item}="${BOOTCODE_LK_PRJ_LIST}" || echo "${BOOTCODE_LK_PRJ_LIST}"
    return 0
}

function bootcode_lk_git_version_get()
{
    lk_item=$1
    dir=`bootcode_lk_dir_get`

    if [ ! -d "$dir" ]; then
        echo "ERROR! $dir not found!"
        return 1
    fi

    pushd $dir > /dev/null
    lk_version=`git log --pretty=format:'%h' -n 1`
    popd > /dev/null

    [ "$lk_item" != "" ] && export ${lk_item}="${lk_version}" || echo "${lk_version}"
    return 0
}

function bootcode_lk_toolchain_check()
{
    CROSS_COMPILE=asdk64-4.9.4-a53-EL-3.10-g2.19-a64nt-160307

    lk_toolchain_tar_bz2=`bootcode_lk_dir_get`/toolchain/$CROSS_COMPILE.tar.bz2
    lk_tmp_dir=`bootcode_lk_dir_get`/tmp
    lk_toolchain_dir=${lk_tmp_dir}/${CROSS_COMPILE}

    if [ ! -d "$lk_toolchain_dir" ]; then
        echo cross-compiler not found, installing...
        [ ! -d "$lk_tmp_dir" ] && mkdir -p ${lk_tmp_dir}
        tar xfj $lk_toolchain_tar_bz2 -C $lk_tmp_dir
    fi

    if [ ! -d "$lk_toolchain_dir" ]; then
        echo "ERROR! $lk_toolchain_dir not found!"
        return 1
    fi

    export PATH=${lk_toolchain_dir}/bin:$PATH
}

function bootcode_lk_replace_hwsetting()
{
    #TODO
    config_get BOOTCODE_LK_HWSETTING        || return 1
    config_get BOOTCODE_LK_PRJ              || return 2
    inc_dir=`bootcode_lk_dir_get`/tools/$LK_FLASH_WRITER_FOLDER/inc
    prj_inc=${inc_dir}/${BOOTCODE_LK_PRJ}.inc
    sed -i "s/Board_HWSETTING =.*$/Board_HWSETTING = ${BOOTCODE_LK_HWSETTING}/" ${prj_inc}
    return $?
}

function bootcode_lk_revert_hwsetting()
{
    #TODO
    config_get BOOTCODE_LK_HWSETTING        || return 1
    config_get BOOTCODE_LK_PRJ              || return 2
    inc_dir=`bootcode_lk_dir_get`/tools/$LK_FLASH_WRITER_FOLDER/inc
    prj_inc=${BOOTCODE_LK_PRJ}.inc
    [ ! -d "$inc_dir" ] && return 3
    pushd $inc_dir > /dev/null
        git checkout $prj_inc
        ERR=$?
    popd > /dev/null
    return $ERR
}

function bootcode_lk_build_out_dvrboot_config_get()
{
    config_get BOOTCODE_LK_CHIP_ID          || return 1
    bin=`bootcode_lk_dir_get`/build-${BOOTCODE_LK_CHIP_ID}/dvrboot_config
    lk_item=$1
    [ "$lk_item" != "" ] && export ${lk_item}="${bin}" || echo "${bin}"
}

function bootcode_lk_build_out_dvrboot_bin_get()
{
    config_get BOOTCODE_LK_CHIP_ID          || return 1
    bin=`bootcode_lk_dir_get`/build-${BOOTCODE_LK_CHIP_ID}/dvrboot.exe.bin
    lk_item=$1
    [ "$lk_item" != "" ] && export ${lk_item}="${bin}" || echo "${bin}"
}

function bootcode_lk_build_out_hwsetting_bin_get()
{
    config_get BOOTCODE_LK_CHIP_ID          || return 1
    if [ "$BOOTCODE_LK_CHIP_ID" == "rtd1395" ] || [ "$BOOTCODE_LK_CHIP_ID" == "rtd1355" ]; then
        LK_FLASH_WRITER_FOLDER=flash_writer_vm
    fi
    config_get BOOTCODE_LK_HWSETTING        || return 1
    bin=`bootcode_lk_dir_get`/tools/$LK_FLASH_WRITER_FOLDER/image/hw_setting/${BOOTCODE_LK_HWSETTING}.bin
    lk_item=$1
    [ "$lk_item" != "" ] && export ${lk_item}="${bin}" || echo "${bin}"
}

function bootcode_lk_build()
{
    bootcode_lk_type_is_off && return 0
    bootcode_lk_toolchain_check             || return 1
    config_get BOOTCODE_LK_CHIP_ID          || return 2
    config_get BOOTCODE_LK_CUSTOMER_ID      || return 3
    config_get BOOTCODE_LK_CHIP_VERSION     || return 4
    config_get BOOTCODE_LK_HWSETTING        || return 5
    config_get BOOTCODE_LK_PRJ              || return 6
	config_get LK_FW_LOAD            		|| return 7

    lk_dir=`bootcode_lk_dir_get`

    if [ ! -d "$lk_dir" ]; then
        echo "ERROR! $lk_dir not found!"
        return 99
    fi

    BUILD_ID=`bootcode_lk_git_version_get`-`date +%Y_%m_%d_%H%M`

    if [ "$TARGET_CHIP_ARCH" == "arm64" ]; then
        BOOTCODE_LK_BUILD_VERSION=$BOOTCODE_LK_CHIP_ID
    else
        BOOTCODE_LK_BUILD_VERSION=${BOOTCODE_LK_CHIP_ID}_aarch32
    fi

    make_parameters=
    list_add make_parameters ${BOOTCODE_LK_BUILD_VERSION}
    list_add make_parameters -j4
    list_add make_parameters Board_HWSETTING=${BOOTCODE_LK_HWSETTING}
    list_add make_parameters PRJ=${BOOTCODE_LK_PRJ}
    list_add make_parameters CUSTOMER_ID=${BOOTCODE_LK_CUSTOMER_ID}
    list_add make_parameters CHIP_TYPE=${BOOTCODE_LK_CHIP_VERSION}
    list_add make_parameters BUILDID="$BUILD_ID"
    list_add make_parameters LK_FW_LOAD="$LK_FW_LOAD"

    if vmx_is_enable_boot_flow && vmx_is_enable_ultra; then
        LK_ONLY=0
        echo "build lk with vmx ultra mode"
        list_add make_parameters LK_FW_LOAD=0
        list_add make_parameters VMX=1
        list_add make_parameters VMX_ULTRA=1
        list_add make_parameters LK_ONLY=$LK_ONLY
    elif vmx_is_enable_boot_flow; then
        echo "build lk with vmx mode"
        list_add make_parameters LK_FW_LOAD=0
        list_add make_parameters VMX=1
    else
        if ! image_secure_type_is_off; then
            list_add make_parameters LK_FW_LOAD=0
        else
            list_add make_parameters LK_FW_LOAD=1
      fi
    fi

	if 	[ "$BOOTCODE_LK_CHIP_ID" == "rtd1395" ]; then
        LK_FLASH_WRITER_FOLDER=flash_writer_vm
		if drm_type_is_off; then
			cp $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/image/tee_os/$BOOTCODE_LK_CHIP_VERSION/fsbl-os-00.00.bin.bypass.enc $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/bootimage/$BOOTCODE_LK_CHIP_ID/$BOOTCODE_LK_CHIP_VERSION/fsbl-os-00.00.bin.enc
		else
			cp $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/image/tee_os/$BOOTCODE_LK_CHIP_VERSION/fsbl-os-00.00.bin.drm.enc $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/bootimage/$BOOTCODE_LK_CHIP_ID/$BOOTCODE_LK_CHIP_VERSION/fsbl-os-00.00.bin.enc
		fi
	else	
		if drm_type_is_off; then
			cp $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/image/tee_os/fsbl-os-00.00.bin.slim $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/bootimage/$BOOTCODE_LK_CHIP_ID/fsbl-os-00.00.bin
		else
			cp $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/image/tee_os/fsbl-os-00.00.bin.enlarge $BOOTCODE_LK_DIR/tools/$LK_FLASH_WRITER_FOLDER/bootimage/$BOOTCODE_LK_CHIP_ID/fsbl-os-00.00.bin
		fi
	fi

    pushd $lk_dir > /dev/null
        #bootcode_lk_replace_hwsetting || return 9
        make ${make_parameters}
        ERR=$?
        #bootcode_lk_revert_hwsetting || return 10
    popd > /dev/null

    if [ "$ERR" != "0" ]; then
        echo "ERROR! make failed!"
        echo make ${make_parameters}
        return $ERR
    fi

    if [ "$LK_ONLY" = "1" ]; then
        echo "LK_ONLY=$LK_ONLY"
        build_out_file_check=
        list_add build_out_file_check `bootcode_lk_lk_bin_get`
    else
        echo "LK_ONLY=$LK_ONLY"
        build_out_file_check=
        list_add build_out_file_check `bootcode_lk_build_out_dvrboot_config_get`
        list_add build_out_file_check `bootcode_lk_build_out_dvrboot_bin_get`
        list_add build_out_file_check `bootcode_lk_build_out_hwsetting_bin_get`
        list_add build_out_file_check `bootcode_lk_bootloader_tar_get`
        list_add build_out_file_check `bootcode_lk_lk_bin_get`
    fi

    echo -----------------------------------------
    for f in $build_out_file_check
    do
        if [ ! -e "$f" ]; then
            echo file not found! $f
            ERR=1
        else
            ls -l $f
        fi
    done
    echo -----------------------------------------

    if vmx_is_enable_boot_flow; then
	vmx_update_lk_bootloader_in_image $lk_dir/build-${BOOTCODE_LK_CHIP_ID}/lk.bin $lk_dir/bootloader_lk.tar
    fi

    return $ERR
}
