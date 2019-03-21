#!/bin/bash
[ "$ENV_IMAGE_SOURCE" != "" ] && return
ENV_IMAGE_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
source $SCRIPTDIR/env_android.sh
source $SCRIPTDIR/env_kernel.sh
source $SCRIPTDIR/env_rtksrc.sh
source $SCRIPTDIR/env_firmware.sh
source $SCRIPTDIR/env_bootcode.sh
source $SCRIPTDIR/env_platform.sh
source $SCRIPTDIR/env_drm.sh
source $SCRIPTDIR/env_image_secure.sh
source $SCRIPTDIR/env_secure_func.sh
source $SCRIPTDIR/env_vmx.sh
source $SCRIPTDIR/env_hdcp.sh
source $SCRIPTDIR/env_xen.sh
source $SCRIPTDIR/env_ca.sh

IMAGEDIR=$TOPDIR/image_file

function image_device_tree_name_preapre()
{
    config_get IMAGE_TARGET_CHIP    || return 1
    config_get IMAGE_TARGET_BOARD   || return 2
    config_get IMAGE_LAYOUT_TYPE    || return 3
    config_get IMAGE_DRAM_SIZE      || return 4

    config_get CA_TYPE none

    case "$IMAGE_TARGET_CHIP" in
        phoenix)
            DTB_PREFIX=rtd-119x
            ;;
        kylin)
            case "$IMAGE_TARGET_BOARD" in
                giraffe | monarch | milii )
                    DTB_PREFIX=rtd-1295
                    ;;
                saola | pelican | pinnata )
                    DTB_PREFIX=rtd-1296
                    ;;
                *)
                    echo -e "$0 \033[47;31mUnknown IMAGE_TARGET_BOARD($IMAGE_TARGET_BOARD) \033[0m"
                    exit 1
                    ;;
            esac
            ;;
        hercules)
            case "$IMAGE_TARGET_BOARD" in
                lionskin )
                    DTB_PREFIX=rtd-1395
                    ;;
                gnarledclub )
                    DTB_PREFIX=rtd-1355
                    ;;
                arete )
                    DTB_PREFIX=rtd-1395
                    ;;
                *)
                    echo -e "$0 \033[47;31mUnknown IMAGE_TARGET_BOARD($IMAGE_TARGET_BOARD) \033[0m"
                    exit 1
                    ;;
            esac
            ;;
        thor)
            case "$IMAGE_TARGET_BOARD" in
                mjolnir | megingjord )
                    DTB_PREFIX=rtd-1619
                    ;;
                *)
                    echo -e "$0 \033[47;31mUnknown IMAGE_TARGET_BOARD($IMAGE_TARGET_BOARD) \033[0m"
                    exit 1
                    ;;
            esac
            ;;
    esac

    ORIGIN_DTS_NAME=$DTB_PREFIX-$IMAGE_TARGET_BOARD-$IMAGE_DRAM_SIZE

    if drm_type_is_with_svp ; then
        RESCUE_DTS_NAME=$DTB_PREFIX-qa-rescue-tee
    else
        if [ "$IMAGE_TARGET_BOARD" = "arete" ] ; then
            # rtd-1395-arete-rescue
            if [ "${IMAGE_DRAM_SIZE:0:3}" = "1GB" ] ; then
                RESCUE_DTS_NAME=$DTB_PREFIX-qa-rescue
            else
                RESCUE_DTS_NAME=$DTB_PREFIX-$IMAGE_TARGET_BOARD-rescue
            fi
        else
            RESCUE_DTS_NAME=$DTB_PREFIX-qa-rescue
        fi
    fi

	#if [ "${VMX_TYPE}" == "ultra" ] && vmx_is_drm_enable; then
    if [ "${VMX_TYPE}" == "ultra" ] && vmx_is_drm_enable && drm_type_is_with_svp; then
        RESCUE_DTS_NAME=$DTB_PREFIX-qa-rescue-vmx
    elif drm_type_is_with_svp && melon_is_drm_enable ; then
        RESCUE_DTS_NAME=$DTB_PREFIX-qa-rescue-melon-tee
    elif drm_type_is_with_svp ; then
        RESCUE_DTS_NAME=$DTB_PREFIX-qa-rescue-tee
    else
        if [ "$IMAGE_TARGET_BOARD" = "arete" ] ; then
            # rtd-1395-arete-rescue
            if [ "${IMAGE_DRAM_SIZE:0:3}" = "1GB" ] ; then
                RESCUE_DTS_NAME=$DTB_PREFIX-qa-rescue
            else
                RESCUE_DTS_NAME=$DTB_PREFIX-$IMAGE_TARGET_BOARD-rescue
            fi
        else
            RESCUE_DTS_NAME=$DTB_PREFIX-qa-rescue
        fi
    fi

    # for legacy : overwrite
    case "$IMAGE_TARGET_BOARD" in
        qa)
            ORIGIN_DTS_NAME=rtd-119x-qa
            RESCUE_DTS_NAME=rtd-119x-qa-rescue
            ;;
        horseradish)
            ORIGIN_DTS_NAME=rtd-119x-horseradish
            RESCUE_DTS_NAME=rtd-119x-qa-rescue
            ;;
        horseradish-lm)
            ORIGIN_DTS_NAME=rtd-119x-horseradish-lm
            RESCUE_DTS_NAME=rtd-119x-qa-rescue-lm
            ;;
        horseradish-lm-uhd)
            ORIGIN_DTS_NAME=rtd-119x-horseradish-lm-uhd
            RESCUE_DTS_NAME=rtd-119x-qa-rescue-lm
            ;;
        pegasus)
            ORIGIN_DTS_NAME=rtd-119x-pegasus
            RESCUE_DTS_NAME=rtd-119x-qa-rescue
            ;;
    esac

    if [ "$IMAGE_LAYOUT_TYPE" = "sata" ] && [ "$IMAGE_TARGET_BOARD" = "giraffe" ]; then
        ORIGIN_DTS_NAME=$DTB_PREFIX-$IMAGE_TARGET_BOARD-$IMAGE_DRAM_SIZE.SATA
    fi

    #if vmx_is_enable_ca_control ; then
    if vmx_is_drm_enable ; then
        VMX_DTS_NAME=${ORIGIN_DTS_NAME}-stb
        file=`kernel_device_tree_dir_get`/${VMX_DTS_NAME}.dts
        [ -e "$file" ] && ORIGIN_DTS_NAME=${VMX_DTS_NAME}
    fi


    if drm_type_is_with_svp ; then
        TEE_DTS_NAME=${ORIGIN_DTS_NAME}-tee
  	    #if vmx_is_enable_ca_control ; then
        if vmx_is_drm_enable ; then
		    TEE_DTS_NAME=${TEE_DTS_NAME}-vmx
        fi
        file=`kernel_device_tree_dir_get`/${TEE_DTS_NAME}.dts
        [ -e "$file" ] && ORIGIN_DTS_NAME=${TEE_DTS_NAME}
    fi

    if drm_type_is_without_svp ; then
        TEE_DTS_NAME=${ORIGIN_DTS_NAME}-tee
        #if vmx_is_enable_ca_control ; then
        if vmx_is_drm_enable ; then
		    TEE_DTS_NAME=${TEE_DTS_NAME}-vmx
        fi
        file=`kernel_device_tree_dir_get`/${TEE_DTS_NAME}.dts
        [ -e "$file" ] && ORIGIN_DTS_NAME=${TEE_DTS_NAME}
    fi
    if vmx_is_enable_boot_flow ; then
        VMX_DTS_NAME=${ORIGIN_DTS_NAME}-vmx
        file=`kernel_device_tree_dir_get`/${VMX_DTS_NAME}.dts
        [ -e "$file" ] && ORIGIN_DTS_NAME=${VMX_DTS_NAME}
    fi
    if image_enable_ab_system ; then
        AB_DTS_NAME=${ORIGIN_DTS_NAME}-ab
        file=`kernel_device_tree_dir_get`/${AB_DTS_NAME}.dts
        [ -e "$file" ] && ORIGIN_DTS_NAME=${AB_DTS_NAME}
    fi
    if secure_func_dmverity_is_enable && [ "$DTB_PREFIX" = "rtd-1395" ] && [ "$IMAGE_TARGET_BOARD" = "lionskin" ] && [ "$IMAGE_DRAM_SIZE" = "2GB" ]; then
        AB_DTS_NAME=${ORIGIN_DTS_NAME}-verity
        file=`kernel_device_tree_dir_get`/${AB_DTS_NAME}.dts
        [ -e "$file" ] && ORIGIN_DTS_NAME=${AB_DTS_NAME}
    fi

    case "$CA_TYPE" in
        nocs32)
            DTB_CA_TYPE=melon
            ORIGIN_DTS_NAME=$ORIGIN_DTS_NAME-$DTB_CA_TYPE
            ;;
        *)
            ;;
    esac

    export ORIGIN_DTS_NAME
    export RESCUE_DTS_NAME
    return 0
}

function image_origin_dts_get()
{
    image_device_tree_name_preapre
    file=`kernel_device_tree_dir_get`/${ORIGIN_DTS_NAME}.dts
    [ "$1" != "" ] && export $1=${file} || echo ${file}
    return 0
}

function image_origin_dtb_get()
{
    image_device_tree_name_preapre
    file=`kernel_device_tree_dir_get`/${ORIGIN_DTS_NAME}.dtb
    [ "$1" != "" ] && export $1=${file} || echo ${file}
    return 0
}

function image_origin_dtbo_get()
{
    case "$IMAGE_TARGET_CHIP" in
        hercules)
            DTBO_NAME=rtd-139x
            ;;
        thor)
            DTBO_NAME=rtd-16xx
            ;;
    esac
    file=`kernel_device_tree_dir_get`/dtbo/${DTBO_NAME}.dtboimg
    [ "$1" != "" ] && export $1=${file} || echo ${file}
    return 0
}

function image_origin_dts_version_get()
{
    image_device_tree_name_preapre
    file=`kernel_device_tree_dir_get`/${ORIGIN_DTS_NAME}.dts
    version=
    if [ -e "${file}" ]; then
        pushd `kernel_device_tree_dir_get` > /dev/null
            version=`git log --pretty=format:'%h' -n 1 ${ORIGIN_DTS_NAME}.dts`
        popd > /dev/null
    fi

    [ "$1" != "" ] && export $1=${version} || echo ${version}
    return 0
}

function image_rescue_dts_get()
{
    image_device_tree_name_preapre
    file=`kernel_device_tree_dir_get`/${RESCUE_DTS_NAME}.dts
    [ "$1" != "" ] && export $1=${file} || echo ${file}
    return 0
}

function image_rescue_dtb_get()
{
    image_device_tree_name_preapre
    file=`kernel_device_tree_dir_get`/${RESCUE_DTS_NAME}.dtb
    [ "$1" != "" ] && export $1=${file} || echo ${file}
    return 0
}

function image_rescue_dts_version_get()
{
    image_device_tree_name_preapre
    file=`kernel_device_tree_dir_get`/${RESCUE_DTS_NAME}.dts
    version=
    if [ -e "${file}" ]; then
        pushd `kernel_device_tree_dir_get` > /dev/null
            version=`git log --pretty=format:'%h' -n 1 ${RESCUE_DTS_NAME}.dts`
        popd > /dev/null
    fi

    [ "$1" != "" ] && export $1=${version} || echo ${version}
    return 0
}

function image_dram_size_MB_get()
{
    config_get IMAGE_DRAM_SIZE
    local dram_size=0
    case "$IMAGE_DRAM_SIZE" in
        384MB | 384MB.CMAx2)
            dram_size=384
            ;;
        512MB.CMAx2 )
            dram_size=512
            ;;
        768MB.CMAx2)
            dram_size=768
            ;;
        1GB | 1GB.CMAx2 | 1GB.atv | 1GB.atv-avb | xenott.low)
            dram_size=1024
            ;;
        1.5GB | 1.5GB.atv-avb)
            dram_size=1536
            ;;
        2GB | 2GB-avb | xenott | xenott.CMAx2)
            dram_size=2048
            ;;
        3GB | xenott-3GB)
            dram_size=3072
            ;;
        4GB)
            dram_size=4096
            ;;
        *)
            dram_size=0
            ;;
    esac
    [ "$1" != "" ] && export $1=${dram_size} || echo ${dram_size}
    return 0
}

function image_dram_size_config()
{
    xen_config
    IMAGE_DRAM_SIZE_LIST=
    list_add IMAGE_DRAM_SIZE_LIST 384MB
    list_add IMAGE_DRAM_SIZE_LIST 384MB.CMAx2
    list_add IMAGE_DRAM_SIZE_LIST 512MB.CMAx2
    list_add IMAGE_DRAM_SIZE_LIST 768MB.CMAx2
    list_add IMAGE_DRAM_SIZE_LIST 1GB
    list_add IMAGE_DRAM_SIZE_LIST 1GB.CMAx2
    list_add IMAGE_DRAM_SIZE_LIST 1GB.atv
    list_add IMAGE_DRAM_SIZE_LIST 1GB.atv-avb
    list_add IMAGE_DRAM_SIZE_LIST 1.5GB
    list_add IMAGE_DRAM_SIZE_LIST 1.5GB.atv-avb
    list_add IMAGE_DRAM_SIZE_LIST 2GB
    list_add IMAGE_DRAM_SIZE_LIST 2GB-avb
    list_add IMAGE_DRAM_SIZE_LIST 3GB
    list_add IMAGE_DRAM_SIZE_LIST 4GB
    if xen_is_enable ; then
        list_add IMAGE_DRAM_SIZE_LIST xenott
        list_add IMAGE_DRAM_SIZE_LIST xenott-3GB
        list_add IMAGE_DRAM_SIZE_LIST xenott.CMAx2
        list_add IMAGE_DRAM_SIZE_LIST xenott.low
    fi
    config_get_menu IMAGE_DRAM_SIZE IMAGE_DRAM_SIZE_LIST 1GB
}

function image_gen_version()
{
    rtk_version_file=${TOPDIR}/rtk_version.txt  # realtek version information
    echo "Realtek Version Information:"                 >  ${rtk_version_file}
    echo "Android `android_export_version_get`"         >> ${rtk_version_file}
    echo "DvdPlayer `rtksrc_export_version_get`"        >> ${rtk_version_file}
    echo "FW `firmware_export_version_get`"             >> ${rtk_version_file}
    echo "Bootcode `bootcode_export_version_get`"       >> ${rtk_version_file}
    echo "linux-kernel `kernel_export_version_get`"     >> ${rtk_version_file}
    echo "AndroidDT `image_origin_dts_version_get`"     >> ${rtk_version_file}
    echo "RescueDT `image_rescue_dts_version_get`"      >> ${rtk_version_file}
    echo "AndroidRootfs N/A"                            >> ${rtk_version_file}
    echo "RescueRootfs N/A"                             >> ${rtk_version_file}
    echo "Mali N/A"                                     >> ${rtk_version_file}
    echo "NAS N/A"                                      >> ${rtk_version_file}
    cp ${rtk_version_file} `android_vendor_dir_get`/resource/
}

function image_enable_ab_system()
{
    config_get ENABLE_AB_SYSTEM
    [ "$ENABLE_AB_SYSTEM" = "true" ] && return 0 || return 1
}

function image_is_install_bootloader()
{
    config_get IMAGE_INSTALL_BOOTLOADER
    [ "$IMAGE_INSTALL_BOOTLOADER" = "true" ] && return 0 || return 1
}

function image_bootloader_copy()
{
    ERR=0
    #TODO uboot32/uboot64
    src_file=`bootcode_lk_bootloader_tar_get`
    des_dir=${IMAGEDIR}/components/packages/package5

    if [ ! -e "${des_dir}" ]; then
        echo "ERROR! [image_bootloader_copy] $des_dir not found!"
        return 1
    fi

    if [ ! -e "${src_file}" ]; then
        echo "ERROR! [image_bootloader_copy] $src_file not found!"
        return 1
    fi

    if [ "$IMAGE_TARGET_CHIP" = "thor" ]; then
        pushd $des_dir
            bootcode_dir=`bootcode_lk_dir_get`/tools/$LK_FLASH_WRITER_NV_FOLDER/Bind
            cp $bootcode_dir/uda_emmc.bind.bin $bootcode_dir/boot_emmc.bind.bin ./
            tar cvf bootloader_lk.tar uda_emmc.bind.bin boot_emmc.bind.bin
            rm uda_emmc.bind.bin boot_emmc.bind.bin
        popd
    else
        cp -vf $src_file $des_dir/
    fi

    ERR=$?
    return $ERR
}

function image_tee_fw_is_enable()
{
    config_get IMAGE_TEE_FW
    [ "$IMAGE_TEE_FW" = "true" ] && return 0 || return 1
}

function image_is_offline_gen()
{
    config_get IMAGE_OFFLINE_GEN
    [ "$IMAGE_OFFLINE_GEN" = "true" ] && return 0 || return 1
}

function image_config_prepare()
{
    AUDIOFW_DEBUG=$TOPDIR/bluecore.audio.nofile

    TARGET_PACKAGE=package5
    PACKAGE_DIR=$IMAGEDIR/components/packages/$TARGET_PACKAGE

    #ReaLis
    TEEFW=$PACKAGE_DIR/tee.bin
    BUILD_TEE=y

    IMAGE_LAYOUT_TYPE_LIST="emmc nand sata"
    IMAGE_LAYOUT_SIZE_LIST="4gb 8gb GPT_HDD"
    IMAGE_INSTALL_DTB_LIST="0 1"
    IMAGE_INSTALL_FACTORY_LIST="0 1"
    IMAGE_CUSTOM_BOOTANIM_DEFAULT="default"
    IMAGE_CUSTOM_BOOTANIM_LIST="$IMAGE_CUSTOM_BOOTANIM_DEFAULT qa_supplement/addons/system/media/bootanimation.zip"
    IMAGE_CUSTOM_BOOTLOGO_DEFAULT="qa_supplement/logo/bootfile-realtek.image"
    IMAGE_CUSTOM_BOOTLOGO_LIST="$IMAGE_CUSTOM_BOOTLOGO_DEFAULT qa_supplement/logo/bootfile-android.image qa_supplement/logo/bootfile-androidtv.image"

    IMAGE_TARGET_CHIP_LIST=
    list_add IMAGE_TARGET_CHIP_LIST thor
    list_add IMAGE_TARGET_CHIP_LIST hercules
    list_add IMAGE_TARGET_CHIP_LIST kylin
    list_add IMAGE_TARGET_CHIP_LIST phoenix

    config_get KERNEL_TARGET_CHIP
    IMAGE_TARGET_CHIP_LIST_DEFAULT=$KERNEL_TARGET_CHIP
    config_get_menu IMAGE_TARGET_CHIP IMAGE_TARGET_CHIP_LIST ${IMAGE_TARGET_CHIP_LIST_DEFAULT}


    IMAGE_TARGET_BOARD_LIST=
    case "$IMAGE_TARGET_CHIP" in
        phoenix)
            list_add IMAGE_TARGET_BOARD_LIST chiron
            list_add IMAGE_TARGET_BOARD_LIST fpga
            list_add IMAGE_TARGET_BOARD_LIST generic
            list_add IMAGE_TARGET_BOARD_LIST horseradish
            list_add IMAGE_TARGET_BOARD_LIST horseradish-lm
            list_add IMAGE_TARGET_BOARD_LIST mustang
            list_add IMAGE_TARGET_BOARD_LIST nas
            list_add IMAGE_TARGET_BOARD_LIST pace
            list_add IMAGE_TARGET_BOARD_LIST pegasus
            list_add IMAGE_TARGET_BOARD_LIST qa
            DEFAULT_TARGET_BOARD=horseradish
            ;;
        kylin)
            list_add IMAGE_TARGET_BOARD_LIST giraffe
            list_add IMAGE_TARGET_BOARD_LIST saola
            list_add IMAGE_TARGET_BOARD_LIST monarch
            list_add IMAGE_TARGET_BOARD_LIST pelican
            list_add IMAGE_TARGET_BOARD_LIST milii
            list_add IMAGE_TARGET_BOARD_LIST pinnata
            DEFAULT_TARGET_BOARD=giraffe
            ;;
        hercules)
            list_add IMAGE_TARGET_BOARD_LIST lionskin
            list_add IMAGE_TARGET_BOARD_LIST gnarledclub
            list_add IMAGE_TARGET_BOARD_LIST arete
            DEFAULT_TARGET_BOARD=lionskin
            ;;
        thor)
            list_add IMAGE_TARGET_BOARD_LIST mjolnir
            list_add IMAGE_TARGET_BOARD_LIST megingjord
            DEFAULT_TARGET_BOARD=mjolnir
            ;;
        *)
            echo -e "$0 \033[47;31mERROR! IMAGE_TARGET_CHIP($IMAGE_TARGET_CHIP) not found!\033[0m"
            exit 1
            ;;
    esac

    IMAGE_CHIP_REVISION_LIST=
    case "$IMAGE_TARGET_CHIP" in
        phoenix)
            list_add IMAGE_CHIP_REVISION_LIST X
            DEFAULT_CHIP_REVISION=X
            ;;
        kylin)
            list_add IMAGE_CHIP_REVISION_LIST A00/A01
            list_add IMAGE_CHIP_REVISION_LIST B00/B01
            DEFAULT_CHIP_REVISION=B00/B01
            ;;
        hercules)
            list_add IMAGE_CHIP_REVISION_LIST A00
            list_add IMAGE_CHIP_REVISION_LIST A01
            DEFAULT_CHIP_REVISION=A00
            ;;
        thor)
            list_add IMAGE_CHIP_REVISION_LIST A00
            DEFAULT_CHIP_REVISION=A00
            ;;
        *)
            echo -e "$0 \033[47;31mERROR! IMAGE_TARGET_CHIP($IMAGE_TARGET_CHIP) not found!\033[0m"
            exit 1
            ;;
    esac

}

function image_config()
{
    kernel_config
    image_config_prepare


    config_get_menu  IMAGE_CHIP_REVISION    IMAGE_CHIP_REVISION_LIST    $DEFAULT_CHIP_REVISION

    image_dram_size_config

    config_get_bool  IMAGE_ADJ_VM           false
    config_get_menu  IMAGE_LAYOUT_TYPE      IMAGE_LAYOUT_TYPE_LIST      emmc
    config_get_menu  IMAGE_LAYOUT_SIZE      IMAGE_LAYOUT_SIZE_LIST      4gb
    if [ "$IMAGE_LAYOUT_TYPE" == "emmc" ] && [ "$IMAGE_LAYOUT_SIZE" == "8gb" ]; then
        config_get_bool IMAGE_LAYOUT_USE_EMMC_SWAP false
    else
        config_set IMAGE_LAYOUT_USE_EMMC_SWAP false
    fi
    config_get_menu  IMAGE_INSTALL_DTB      IMAGE_INSTALL_DTB_LIST      1
    config_get_menu  IMAGE_TARGET_BOARD     IMAGE_TARGET_BOARD_LIST     $DEFAULT_TARGET_BOARD
    config_get_menu  IMAGE_INSTALL_FACTORY  IMAGE_INSTALL_FACTORY_LIST  0
    config_get_bool  IMAGE_RTK_BOOT_LOGO    true
    config_get_menu  IMAGE_CUSTOM_BOOTANIM  IMAGE_CUSTOM_BOOTANIM_LIST  $IMAGE_CUSTOM_BOOTANIM_DEFAULT
    config_get_menu  IMAGE_CUSTOM_BOOTLOGO  IMAGE_CUSTOM_BOOTLOGO_LIST  $IMAGE_CUSTOM_BOOTLOGO_DEFAULT
    config_get_bool  IMAGE_USE_DAILYBUILD_AUDIOFW true

    # seperate tee_fw, install_bootloder, offline_gen from secure option
    config_get_bool  IMAGE_TEE_FW             false
    config_get_bool  IMAGE_INSTALL_BOOTLOADER false
    config_get_bool  IMAGE_OFFLINE_GEN        false
    config_get_bool  ENABLE_AB_SYSTEM         false

    image_checkout_config
    image_secure_config
    image_daily_build_dir_warning_show
    firmware_config
    secure_func_config
    return 0
}

function image_checkout_config()
{
    config_get MANIFEST_BRANCH

    IMAGE_CHECKOUT_BRANCH_LIST=
    list_add IMAGE_CHECKOUT_BRANCH_LIST TEE0518
    list_add IMAGE_CHECKOUT_BRANCH_LIST phoenix
    list_add IMAGE_CHECKOUT_BRANCH_LIST image_file_creator.CustBranch-160819
    list_add IMAGE_CHECKOUT_BRANCH_LIST image_file_creator.AskeyBranch-20160615-959880
    list_add IMAGE_CHECKOUT_BRANCH_LIST image_file_creator_CustBranch-QA160627
    list_add IMAGE_CHECKOUT_BRANCH_LIST image_file_creator.J.Hopkins-1004633
    list_add IMAGE_CHECKOUT_BRANCH_LIST image_file_creator.SKBBranch-170222-1007933
    list_add IMAGE_CHECKOUT_BRANCH_LIST image_file_creator.EltexBranch-170724
    list_add IMAGE_CHECKOUT_BRANCH_LIST image_file_creator
    IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT=
    if [ "$BRANCH_QA_TARGET" = "TEE0518" ]; then
        IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT=TEE0518
    else
        case "$IMAGE_TARGET_CHIP" in
            phoenix)
                IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT=phoenix
                ;;
            kylin | hercules | thor)
                case "$MANIFEST_BRANCH" in
                    origin/phoenix-mm-6.0.0-b/trunk-6.0.0_r1-b/kernel-4.1.7_RTD1295_WD_NAS-20160730 | origin/phoenix-mm-6.0.0-b/WDBranch-20161014)
                        IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT=image_file_creator.CustBranch-160819
                        ;;
                    origin/phoenix-mm-6.0.0-b/AskeyBranch-20160615)
                        IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT=image_file_creator.AskeyBranch-20160615-959880
                        ;;
                    origin/phoenix-mm-6.0.0-b/CustBranch-QA160627 | origin/phoenix-mm-6.0.0-b/CustBranch-QA160627-b/Taixin | origin/phoenix-mm-6.0.0-b/CustBranch-QA160627-b/CustBranch-QA160627-nuplayer-2016-11-17)
                        IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT=image_file_creator_CustBranch-QA160627
                        ;;
                    origin/phoenix-mm-6.0.0-b/QA160215-b/J.HopkinsBranch-Tag20161101)
                        IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT=image_file_creator.J.Hopkins-1004633
                        ;;
                    origin/phoenix-mm-6.0.0-b/CustBranch-QA160627-b/CustBranch-QA160627-nuplayer-2016-11-17-b/SKBroadband-Tag-QA160627-nuplayer_Kylin_2017-01-13_SQA_Dailybuild_NAS)
                        IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT=image_file_creator.SKBBranch-170222-1007933
                        ;;
                    origin/phoenix-mm-6.0.0-b/QA160215-b/eltex-170724)
                        IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT=image_file_creator.EltexBranch-170724
                        ;;
                    *)
                        IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT=image_file_creator
                        ;;
                esac
                ;;
        esac
    fi
    if [ "$IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT" = "" ]; then
        echo "[ERROR] IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT=$IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT"
        return 1
    fi
    config_get_menu IMAGE_CHECKOUT_BRANCH IMAGE_CHECKOUT_BRANCH_LIST $IMAGE_CHECKOUT_BRANCH_LIST_DEFAULT

    return 0
}

function image_daily_build_dir_warning_show()
{
    DAILY_BUILD_DIR_NEW=$IMAGEDIR/dailybuild/$BRANCH_PARENT
    DAILY_BUILD_DIR_OLD=$IMAGEDIR/dailybuild/$BRANCH_QA_TARGET
    if [ ! -d $DAILY_BUILD_DIR_NEW ] && [ ! -d $DAILY_BUILD_DIR_OLD ]; then
        echo -e "\033[47;31m [WARNING] $DAILY_BUILD_DIR_OLD or $DAILY_BUILD_DIR_NEW not found, use default dailybuild instead\033[0m"
    fi
}

function image_daily_build_dir_get()
{
    dirnew=$IMAGEDIR/dailybuild/$BRANCH_PARENT
    dirold=$IMAGEDIR/dailybuild/$BRANCH_QA_TARGET
    dirdef=$IMAGEDIR/dailybuild/default
    if [ -d $dirnew ]; then  # first search for common dailybuild
        dir=$dirnew
    elif [ -d $dirold ]; then # second search for specific dailybuild
        dir=$dirold
    else                     # third search for default dailybuild
        dir=$dirdef
    fi
	if [ "$BRANCH_QA_TARGET" = "trunk-7.0-b/kernel-4.9-b/hercules" ]||[ "$BRANCH_QA_TARGET" = "trunk-7.0-b/kernel-4.9-b/hercules_DMX" ]||[ "$BRANCH_QA_TARGET" = "trunk-7.0-b/kernel-4.9-b/hercules-b/CHTMOD-TAG-main_trunk-7.0_Hercules_2018-03-16" ]||[ "$BRANCH_QA_TARGET" = "trunk-7.0-b/kernel-4.9-b/hercules-b/DMX-main_trunk-7.0_Hercules" ]; then
		dir=$dirold
	fi
    [ "$1" != "" ] && export $1=${dir} || echo ${dir}
    return 0
}

function firmware_daily_build_dir_get()
{
    config_get FIRMWARE_TARGET_CHIP
    local dir=
    local search_list=
    case "$BRANCH_QA_TARGET" in
        trunk-7.0-b/kernel-4.9-b/hercules | trunk-7.0-b/kernel-4.9-b/hercules-b/CHTMOD-TAG-main_trunk-7.0_Hercules_2018-03-16 )
            list_add search_list $IMAGEDIR/dailybuild/$BRANCH_QA_TARGET
            list_add search_list $IMAGEDIR/dailybuild/default
            ;;
        *)
            list_add search_list $IMAGEDIR/dailybuild/audio-fw/$FIRMWARE_TARGET_CHIP
            list_add search_list $IMAGEDIR/dailybuild/audio-fw
            list_add search_list $IMAGEDIR/dailybuild/$BRANCH_QA_TARGET
            list_add search_list $IMAGEDIR/dailybuild/default
            ;;
    esac

    for d in $search_list
    do
        if [ -d $d ]; then
            dir=$d
            break;
        fi
    done

    [ "$1" != "" ] && export $1=${dir} || echo ${dir}
    return 0
}

function image_daily_build_bin_list_get()
{
    TARGET_PACKAGE=package5
    bin_list=
    list_add bin_list `image_daily_build_dir_get`/$TARGET_PACKAGE/system/bin/DvdPlayer
    list_add bin_list `image_daily_build_dir_get`/$TARGET_PACKAGE/system/bin/ALSADaemon
    list_add bin_list `image_daily_build_dir_get`/$TARGET_PACKAGE/system/bin/fb_init
    list_add bin_list `image_daily_build_dir_get`/$TARGET_PACKAGE/system/bin/RtkKeyset
    [ "$1" != "" ] && export $1=${bin_list} || echo ${bin_list}
    return 0
}

function image_firmware_image_get()
{
    config_get IMAGE_USE_DAILYBUILD_AUDIOFW
    TARGET_PACKAGE=package5

    AUDIOFW_ZIP=
    AUDIOFW_MAP=

    if [ "$IMAGE_USE_DAILYBUILD_AUDIOFW" != "true" ]; then
        firmware_image_zip_get AUDIOFW_ZIP
        firmware_image_map_get AUDIOFW_MAP
        if [ "$AUDIOFW_ZIP" = "" ] || [ "$AUDIOFW_MAP" = "" ]; then
            echo -e "\033[47;31m [WARNING] audiofw image not found!\033[0m"
            echo -e "\033[47;31m [WARNING] IMAGE_USE_DAILYBUILD_AUDIOFW : false => true \033[0m"
            config_set IMAGE_USE_DAILYBUILD_AUDIOFW true
        fi
    fi

    if [ "$IMAGE_USE_DAILYBUILD_AUDIOFW" = "true" ]; then
        config_get FIRMWARE_SUBVERSION
        AUDIOFW_ZIP_FILE=`firmware_daily_build_dir_get`/$TARGET_PACKAGE/bluecore.audio.${FIRMWARE_SUBVERSION}.zip
        AUDIOFW_ZIP_DEF=`firmware_daily_build_dir_get`/$TARGET_PACKAGE/bluecore.audio.zip
        if [ -e "$AUDIOFW_ZIP_FILE" ]; then
            AUDIOFW_ZIP=$AUDIOFW_ZIP_FILE
        elif [ -e "$AUDIOFW_ZIP_DEF" ]; then
            AUDIOFW_ZIP=$AUDIOFW_ZIP_DEF
        else
            echo -e "\033[47;31m [WARNING] audio fw image not found!\033[m"
        fi

        AUDIOFW_MAP_FILE=`firmware_daily_build_dir_get`/$TARGET_PACKAGE/System.map.${FIRMWARE_SUBVERSION}.audio
        AUDIOFW_MAP_DEF=`firmware_daily_build_dir_get`/$TARGET_PACKAGE/System.map.audio
        if [ -e "$AUDIOFW_MAP_FILE" ]; then
            AUDIOFW_MAP=$AUDIOFW_MAP_FILE
        elif [ -e "$AUDIOFW_MAP_DEF" ]; then
            AUDIOFW_MAP=$AUDIOFW_MAP_DEF
        else
            echo -e "\033[47;31m [WARNING] audio fw map not found!\033[m"
        fi
    fi

    export AUDIOFW_ZIP
    export AUDIOFW_MAP
    return 0
}

function image_sync()
{
    [ -d $IMAGEDIR ] || return 0;
	pushd $IMAGEDIR
	case "$IMAGE_CHECKOUT_BRANCH" in
		phoenix)
			git pull
			;;
		*)
			if [ "$IMAGE_CHECKOUT_BRANCH" = "image_file_creator_CustBranch-QA160627" ]; then
				git pull
			else
				repo sync --force-sync
			fi
			;;
	esac
    ERR=$?
    popd

    return $ERR;
}

function image_init()
{
    [ ! -d "$IMAGEDIR" ] && mkdir $IMAGEDIR
    pushd $IMAGEDIR > /dev/null
    repo init -u $GERRIT_MANIFEST -b $BRANCH_PARENT/$BRANCH_QA_TARGET -m image_file.xml $REPO_PARA
    popd > /dev/null
    return 0
}

function image_checkout()
{
    ret=0
    if [ ! -d "$IMAGEDIR" ]; then
        config_get IMAGE_CHECKOUT_BRANCH
        config_get MANIFEST_BRANCH
        config_get BRANCH_PARENT
        config_get GERRIT_SERVER
        local git_project=
        local git_branch=
        svn_url=
        case "$IMAGE_CHECKOUT_BRANCH" in
            TEE0518)
                svn_url=http://cadinfo.realtek.com.tw/svn/col/DVR/branches/phoenix/branch_for_TEE/image_file
                ;;
            phoenix)
                git_project=flash_environment_32bit/phoenix/image_file_creator
                ;;
            *)
                if [ "$IMAGE_CHECKOUT_BRANCH" = "image_file_creator_CustBranch-QA160627" ]; then
                    git_project=flash_environment_32bit/kylin/image_file_creator
                    git_branch="-b CustBranch-QA160627"
                fi
                ;;
        esac


        if [ "$git_project" != "" ]; then
            local git_url=${GERRIT_SERVER}/$git_project
            local git_reference=

            config_get_text MIRROR_LOCATION
            git_mirror_location_dir="${MIRROR_LOCATION}/${git_project}.git"
            if [ -d "$git_mirror_location_dir" ]; then
                git_reference=--reference=${git_mirror_location_dir}
            else
                git_reference=
            fi

            echo git clone ${git_url} $IMAGEDIR ${git_branch} ${git_reference}
            git clone ${git_url} $IMAGEDIR ${git_branch} ${git_reference}
        else
            [ -e "$IMAGEDIR/.repo_ready" ] && return 0
			image_init && image_sync && (> $IMAGEDIR/.repo_ready) || return 1
        fi
    fi
    return $?
}

function image_prepare()
{
    kernel_version
    ANDROID_VERSION=`get_android_major_version`
    ANDROID_ROOT=`android_root_dir_get`
    ANDROID_SYSTEM=`android_system_dir_get`
    ANDROID_VENDOR=`android_vendor_dir_get`
	ANDROID_MISC=`android_misc_bin_get`
	ANDROID_SYSTEM_OTHER=`android_system_other_dir_get`
    if [ -d "`android_product_out_dir_get`/vendor" ]; then # separate vendor partition
        HAS_VND_PART="true"
        RTK_BIN=$ANDROID_VENDOR/bin
    else
        HAS_VND_PART="false"
        RTK_BIN=$ANDROID_SYSTEM/bin
    fi
    echo vendor partition:$HAS_VND_PART, copy DvdPlayer and ALSADaemon to $RTK_BIN
    if [ ! -d "$ANDROID_ROOT" ] || [ ! -d "$ANDROID_SYSTEM" ]; then
        echo ERROR! Please check above directories exist! $ANDROID_ROOT $ANDROID_SYSTEM
        return 2
    fi

    [ -d $IMAGEDIR ] || build_cmd image_checkout
    pushd $PACKAGE_DIR > /dev/null
	if ! vmx_is_in_release_mode; then
        [ -e root       ] && rm -rf root
        ln -sf $ANDROID_ROOT root
	fi
        # -----------------------------------------------------------#
        # set vm.min_free_kbytes to 32768 if IMAGE_ADJ_VM is true    #
        # -----------------------------------------------------------#
        sed -i '/write \/proc\/sys\/vm\/min_free_kbytes 8192/d' root/init.rc
        sed -i '/write \/proc\/sys\/vm\/min_free_kbytes 16384/d' root/init.rc
        sed -i '/write \/proc\/sys\/vm\/min_free_kbytes 32768/d' root/init.rc
        sed -i '/start kk_low_mem/d' root/init.rc
        if [ "$IMAGE_ADJ_VM" = "true" ]; then
            if [ "$IMAGE_DRAM_SIZE" = "384MB" ] || [ "$IMAGE_DRAM_SIZE" = "384MB.CMAx2" ]; then
                sed -i 's/on late-init/on late-init\n    write \/proc\/sys\/vm\/min_free_kbytes 8192/' root/init.rc
            else
                sed -i 's/on late-init/on late-init\n    write \/proc\/sys\/vm\/min_free_kbytes 32768/' root/init.rc
            fi
            sed -i 's/#KK_LOW_MEM/#KK_LOW_MEM\n    start kk_low_mem/' root/init.rc
        fi
        # ---------------------------------------------------------- #
        # set vm.extra_free_kbytes to 20480 if IMAGE_ADJ_VM is true  #
        # -----------------------------------------------------------#
        sed -i 's/#on property:sys.sysctl.extra_free_kbytes=*/on property:sys.sysctl.extra_free_kbytes=*/' root/init.rc
        sed -i 's/write \/proc\/sys\/vm\/extra_free_kbytes 20480/write \/proc\/sys\/vm\/extra_free_kbytes ${sys.sysctl.extra_free_kbytes}/' root/init.rc
        if [ "$IMAGE_ADJ_VM" = "true" ]; then
            if [ "$IMAGE_DRAM_SIZE" = "xenott.CMAx2" ] || [ "$IMAGE_DRAM_SIZE" = "xenott.low" ] || [ "$IMAGE_DRAM_SIZE" = "xenott" ]; then
                sed -i 's/write \/proc\/sys\/vm\/extra_free_kbytes ${sys.sysctl.extra_free_kbytes}/write \/proc\/sys\/vm\/extra_free_kbytes 8192/' root/init.rc
            else
                sed -i 's/write \/proc\/sys\/vm\/extra_free_kbytes ${sys.sysctl.extra_free_kbytes}/write \/proc\/sys\/vm\/extra_free_kbytes 20480/' root/init.rc
            fi
        fi
        #------------------------------------------------------------#
        if [ "$IMAGE_ADJ_VM" = "true" ]; then
            cp -f $PWD/root/sbin/kk_default_low_mem.sh $PWD/root/sbin/kk_low_mem.sh
            if [ "$IMAGE_DRAM_SIZE" = "xenott.CMAx2" ] || [ "$IMAGE_DRAM_SIZE" = "xenott.low" ] || [ "$IMAGE_DRAM_SIZE" = "xenott" ]; then
              cp -f $PWD/root/sbin/kk_xen_low_mem.sh $PWD/root/sbin/kk_low_mem.sh
            fi
        fi
        # -----------------------------------------------------------#
	if ! vmx_is_in_release_mode; then
        [ -e system     ] && rm -rf system
        ln -sf $ANDROID_SYSTEM system

        [ -e misc ] && rm -rf misc
        ln -sf $ANDROID_MISC misc.bin

	    [ -e system_other ] && rm -rf system_other
		ln -sf $ANDROID_SYSTEM_OTHER system_other

        if [ "$HAS_VND_PART" = "true" ]; then
            [ -e vendor     ] && rm -rf vendor
            ln -sf $ANDROID_VENDOR vendor
        fi
	fi

        [ ! -e data     ] && mkdir data
        [ ! -e cache    ] && mkdir cache
        if [ "$IMAGE_LAYOUT_TYPE" = "emmc" ] || [ "$IMAGE_LAYOUT_TYPE" = "sata" ]; then
            > data/null_file
            > cache/null_file
        fi

	if ! vmx_is_in_release_mode; then
        KUIMAGE=`kernel_image_get`
        if [ -e $KUIMAGE ]; then
            echo copy uImage:$KUIMAGE
            cp $KUIMAGE $IMAGE_LAYOUT_TYPE.uImage
            dd if=/dev/zero of=$IMAGE_LAYOUT_TYPE.uImage conv=notrunc oflag=append bs=1k count=512 > /dev/null 2>&1

            # fix output size : 6MB
            #SEEK_BYTE=$(stat -c%s $IMAGE_LAYOUT_TYPE.uImage)
            #APPEND_BYTE=`expr 6 \* 1024 \* 1024  - $SEEK_BYTE`
            #dd if=/dev/zero of=$IMAGE_LAYOUT_TYPE.uImage conv=notrunc oflag=append bs=$APPEND_BYTE count=1 > /dev/null 2>&1
        fi

		GOLD_KUIMAGE=`kernel_dir_get`/golden_img/Image
		if [ -e $GOLD_KUIMAGE ] && [ "$SHRINK_GOLDEN_IMG" == "true" ]; then
            echo copy GOLD_KUIMAGE:$GOLD_KUIMAGE
            cp $GOLD_KUIMAGE gold.$IMAGE_LAYOUT_TYPE.uImage
        fi
	fi


        image_firmware_image_get # AUDIOFW_ZIP, AUDIOFW_MAP

        if [ -e $AUDIOFW_DEBUG ]; then
            echo copy audio fw:$AUDIOFW_DEBUG
            cp $AUDIOFW_DEBUG bluecore.audio
            #dd if=/dev/zero of=bluecore.audio conv=notrunc oflag=append bs=1k count=512 > /dev/null 2>&1
            zip bluecore.audio.zip bluecore.audio
        elif [ -e $AUDIOFW_ZIP ]; then
            echo copy audio fw \(zip\) :$AUDIOFW_ZIP
            cp $AUDIOFW_ZIP bluecore.audio.zip
            if [ -e $AUDIOFW_MAP ]; then
                echo copy audio fw \(map\) :$AUDIOFW_MAP
                cp $AUDIOFW_MAP System.map.audio
            fi
        else
            echo -e "\033[47;31m [WARNING] Audio Firmware not found!! ($AUDIOFW_ZIP) \033[0m"
        fi

        ANDROID_DTB=`image_origin_dtb_get`
        if [ -e $ANDROID_DTB ]; then
            echo copy android dtb:$ANDROID_DTB
            cp -f $ANDROID_DTB android.$IMAGE_LAYOUT_TYPE.dtb
        fi
        RESCUE_DTB=`image_rescue_dtb_get`
        if [ -e $RESCUE_DTB ]; then
            echo copy rescue dtb:$RESCUE_DTB
            cp -f $RESCUE_DTB rescue.$IMAGE_LAYOUT_TYPE.dtb
        fi
        DTBO=`image_origin_dtbo_get`
        if [ -e $DTBO ]; then
            echo copy android dtbo:$DTBO
            cp -f $DTBO dtbo.bin
        fi
        PACKAGE_SYSTEM=$PACKAGE_DIR/system

      if ! vmx_is_in_release_mode; then
        MODULE_PATH="modules"
        if [ $ANDROID_VERSION -le 8 ]; then
            echo "******* Before android-9.0, copy kernel module in build image stage *******"
            if [ $ANDROID_VERSION -eq 8 ]; then
                MODULE_PATH="lib/modules"
            fi

            ANDROID_MODULES_DIR=$ANDROID_VENDOR/$MODULE_PATH
            rsync -acP --copy-links `kernel_external_modules_list_get` $ANDROID_MODULES_DIR/
            chmod 644 $ANDROID_MODULES_DIR/*
        else
            echo "******* Since android-9.0, copy kernel module before build android. No modules copied here *******"
        fi
      fi

        if hdcp_tx_tee_en; then
                hdcp_tx_copy_ta
        fi
        #if vmx_is_enable_ca_control ; then
        if vmx_is_drm_enable ; then
		    if [ "${VMX_TYPE}" == "ultra" ] && drm_type_is_with_svp  ; then
				vmx_ca_environment
		    elif [ "${VMX_TYPE}" == "advance" ] ; then
			    vmx_ca_environment
		    fi
        fi


		if config_get_true VMX_CONFIG ; then
			SYSTEMDIR=${TOPDIR}/software_Phoenix_RTK/system
			PACKAGE="package5"
			if [ -e "${SYSTEMDIR}" ]; then
				cp -rfv ${SYSTEMDIR}/src/Unit_test/AndroidDvdPlayer/`vmx_dvdplayer_name_get` `image_daily_build_dir_get`/${PACKAGE}/system/bin/DvdPlayer
				cp -rfv ${SYSTEMDIR}/src/Unit_test/AndroidDvdPlayer/`vmx_dvdplayer_name_get`.debug `image_daily_build_dir_get`/${PACKAGE}/system/bin/DvdPlayer.debug
			else
				cp -rfv `image_daily_build_dir_get`/$PACKAGE/system/bin/`vmx_dvdplayer_name_get` `image_daily_build_dir_get`/${PACKAGE}/system/bin/DvdPlayer
				cp -rfv `image_daily_build_dir_get`/$PACKAGE/system/bin/`vmx_dvdplayer_name_get`.debug `image_daily_build_dir_get`/${PACKAGE}/system/bin/DvdPlayer.debug
			fi
		fi

        if [ $ANDROID_VERSION -le 8 ]; then
            mkdir -p $RTK_BIN
            for f in `image_daily_build_bin_list_get`
            do
                if [ -e "${f}" ]; then
                    echo "copy `basename ${f}` from ${f}"
                    rsync -acP --copy-links ${f} ${RTK_BIN}/
                else
                    echo -e "\033[47;31m [WARNING] `basename ${f}` not found!! ($f) \033[0m"
                fi
            done
        else
            echo "******* Since android-9.0, copy dailybuild prebuilt binaries in android, not here *******"
        fi

        # prepare nocs exe
        #REMINDER: shall be modified in Android 9 and RPCServer_PKG_EXT-03.03.04
        if ca_is_nocs_enable ; then
            echo "******* copy nocs exec to image *******"
            echo "copy cert nocs_reeserver"
            SYSTEMDIR=${TOPDIR}/software_Phoenix_RTK/system
            cp -rfv ${SYSTEMDIR}/src/Drivers/dal/test/cert/cert ${RTK_BIN}/
            cp -rfv ${SYSTEMDIR}/src/Drivers/dal/test/RPCServer_PKG_EXT-03.03.04/nocs_reeserver ${RTK_BIN}/
            cp -rfv ${SYSTEMDIR}/src/Drivers/dal/test/dif/dif $ANDROID_VENDOR/bin
            cp -rfv ${SYSTEMDIR}/src/Drivers/dal/test/dif/serverIP.config $ANDROID_VENDOR/etc
            cp -rfv ${SYSTEMDIR}/src/Drivers/dal/test/dif/scripts/hw_reset.sh $ANDROID_VENDOR/etc
		if melon_is_drm_enable ; then
			melon_ca_environment
		fi
        fi

        config_get IMAGE_CUSTOM_BOOTANIM
        BOOTANIM_PATH=$PACKAGE_SYSTEM/media/bootanimation.zip
        if [ "$IMAGE_CUSTOM_BOOTANIM" == "default" ]; then
            echo "remove $BOOTANIM_PATH"
            rm -f $BOOTANIM_PATH
        else
            mkdir -p $PACKAGE_SYSTEM/media
            if [ -f $IMAGE_CUSTOM_BOOTANIM ]; then             #absolute path
                echo "copy boot animation file: $IMAGE_CUSTOM_BOOTANIM"
                cp -f $IMAGE_CUSTOM_BOOTANIM $BOOTANIM_PATH
            elif [ -f $TOPDIR/$IMAGE_CUSTOM_BOOTANIM ]; then   #relative path
                echo "copy boot animation file: $TOPDIR/$IMAGE_CUSTOM_BOOTANIM"
                cp -f $TOPDIR/$IMAGE_CUSTOM_BOOTANIM $BOOTANIM_PATH
            else
                echo "unable to find $IMAGE_CUSTOM_BOOTANIM"
            fi
        fi

        config_get IMAGE_CUSTOM_BOOTLOGO
        if [ "$IMAGE_CUSTOM_BOOTLOGO" != "unchanged" ]; then
            if [ -f $IMAGE_CUSTOM_BOOTLOGO ]; then             #absolute path
                echo "copy boot logo file: $IMAGE_CUSTOM_BOOTLOGO"
                cp -f $IMAGE_CUSTOM_BOOTLOGO $PACKAGE_DIR/bootfile.image
            elif [ -f $TOPDIR/$IMAGE_CUSTOM_BOOTLOGO ]; then   #relative path
                echo "copy boot logo file: $TOPDIR/$IMAGE_CUSTOM_BOOTLOGO"
                cp -f $TOPDIR/$IMAGE_CUSTOM_BOOTLOGO $PACKAGE_DIR/bootfile.image
            else
                echo "unable to find $IMAGE_CUSTOM_BOOTLOGO"
            fi
        fi

	image_is_install_bootloader && build_cmd image_bootloader_copy

        drm_setup_environment
        image_secure_prepare
    popd > /dev/null

    return 0;
}

function image_update_partition_size()
{
    ANDROID_SYSTEM=`android_system_dir_get`
    ANDROID_VENDOR=`android_vendor_dir_get`
    SYSTEM_SIZE=`du -sm $ANDROID_SYSTEM | cut -f 1` #in MB
    VENDOR_SIZE=`du -sm $ANDROID_VENDOR | cut -f 1` #in MB

    if [ "$IMAGE_LAYOUT_SIZE" == "4gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc
    elif [ "$IMAGE_LAYOUT_SIZE" == "8gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc_8gb
    elif [ "$IMAGE_LAYOUT_SIZE" == "16gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc_16gb
    elif [ "$IMAGE_LAYOUT_SIZE" == "32gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc_32gb
    elif [ "$IMAGE_LAYOUT_SIZE" == "GPT_HDD" ]; then
        LAYOUT_DIR=rtk_generic_sata
    else
        return 1
    fi

    if [ "$IMAGE_TARGET_BOARD" = "monarch" ]; then
        return 0
    fi

    if [ "$IMAGE_TARGET_BOARD" = "pelican" ]; then
        return 0
    fi

    if [ "$IMAGE_LAYOUT_TYPE" == "emmc" ] && [ "$IMAGE_LAYOUT_USE_EMMC_SWAP" == "true" ]; then
        PARTITION_TABLE=$PACKAGE_DIR/customer/$LAYOUT_DIR/partition.emmc_swap_700MB.txt
    else
        PARTITION_TABLE=$PACKAGE_DIR/customer/$LAYOUT_DIR/partition.txt
    fi

    SYS_PARTSIZE=`awk '/^part = system/ {print $7}' $PARTITION_TABLE`
    DAT_PARTSIZE=`awk '/^part = data/ {print $7}' $PARTITION_TABLE`
    VND_PARTSIZE=`awk '/^part = vendor/ {print $7}' $PARTITION_TABLE`
    if [ "$SYS_PARTSIZE" == "" ]; then
        SYS_PARTSIZE=0 #system partition is commented out for now
        #uncomment vendor partition
        sed -i "s/^#part = system \(.*\)/part = system \1/" $PARTITION_TABLE
        ADDITIONAL_DATA_REDUCTION=$((300 * 1024 * 1024))
    else
        ADDITIONAL_DATA_REDUCTION=0
    fi
    if [ "$VND_PARTSIZE" == "" ]; then
        VND_PARTSIZE=0 #vendor partition is commented out for now
    fi
    AVAIL_SPACE=$(($SYS_PARTSIZE + $DAT_PARTSIZE + $VND_PARTSIZE))

    if [ "$HAS_VND_PART" == "true"  ]; then
        #uncomment vendor partition
        sed -i "s/^#part = vendor \(.*\)/part = vendor \1/" $PARTITION_TABLE

        VND_PARTSIZE=$((($VENDOR_SIZE + 64) * 1024 * 1024)) ###DON'T USE 128MB###
        echo adjust vendor partition size to $(($VND_PARTSIZE / 1024 / 1024))MB
        sed -i "s/^part = vendor \(.*\) \(.*\) \(.*\) \(.*\)/part = vendor \1 \2 \3 $VND_PARTSIZE/" $PARTITION_TABLE
    fi

    SYS_PARTSIZE=$(($(($SYSTEM_SIZE + 256)) * 1024 * 1024)) #reserve extra 256MB space for system partition
    echo adjust system partition size to $(($SYS_PARTSIZE / 1024 / 1024))MB
    sed -i "s/^part = system \(.*\) \(.*\) \(.*\) \(.*\)/part = system \1 \2 \3 $SYS_PARTSIZE/" $PARTITION_TABLE

    DAT_PARTSIZE=$(($AVAIL_SPACE - $VND_PARTSIZE - $SYS_PARTSIZE + $ADDITIONAL_DATA_REDUCTION))
    echo adjust data partition size to $(($DAT_PARTSIZE / 1024 / 1024))MB
    sed -i "s/^part = data \(.*\) \(.*\) \(.*\) \(.*\)/part = data \1 \2 \3 $DAT_PARTSIZE/" $PARTITION_TABLE

    # resize logo partition to 16MB
    LOGO_PARTSIZE=$((16 * 1024 * 1024))
    echo adjust logo partition size to $(($LOGO_PARTSIZE / 1024 / 1024))MB
    sed -i "s/^part = logo \(.*\) \(.*\) \(.*\) \(.*\)/part = logo \1 \2 \3 $LOGO_PARTSIZE/" $PARTITION_TABLE

    # uncomment uboot partition
    sed -i "s/^#part = uboot \(.*\)/part = uboot \1/" $PARTITION_TABLE
    # uncomment backup partition
    sed -i "s/^#part = backup \(.*\)/part = backup \1/" $PARTITION_TABLE
    # uncomment verify partition
    sed -i "s/^#part = verify \(.*\)/part = verify \1/" $PARTITION_TABLE

    # comment install partition
    sed -i "s/^part = install \(.*\)/#part = install \1/" $PARTITION_TABLE

    return 0
}

function image_adjust_partition()
{

    if [ "$IMAGE_LAYOUT_SIZE" == "4gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc
    elif [ "$IMAGE_LAYOUT_SIZE" == "8gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc_8gb
    elif [ "$IMAGE_LAYOUT_SIZE" == "16gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc_16gb
    elif [ "$IMAGE_LAYOUT_SIZE" == "32gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc_32gb
    elif [ "$IMAGE_LAYOUT_SIZE" == "GPT_HDD" ]; then
        LAYOUT_DIR=rtk_generic_sata
    else
        return 1
    fi

    PARTITION_TABLE=$PACKAGE_DIR/customer/$LAYOUT_DIR/partition_GPT.txt
    sed -i "s/^part = vbmeta \(.*\)/#part = vbmeta \1/" $PARTITION_TABLE
}

function image_adjust_swap()
{
    if [ "$IMAGE_LAYOUT_SIZE" == "4gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc
    elif [ "$IMAGE_LAYOUT_SIZE" == "8gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc_8gb
    elif [ "$IMAGE_LAYOUT_SIZE" == "16gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc_16gb
    elif [ "$IMAGE_LAYOUT_SIZE" == "32gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc_32gb
    elif [ "$IMAGE_LAYOUT_SIZE" == "GPT_HDD" ]; then
        LAYOUT_DIR=rtk_generic_sata
    else
        return 1
    fi

    PARTITION_TABLE=$PACKAGE_DIR/customer/$LAYOUT_DIR/partition_GPT.txt
    if [ android_is_low_ram ]; then
        echo enable emmc swap for low ram device...
        sed -i "s/^#part = swap \(.*\)/part = swap \1/" $PARTITION_TABLE
    else
        echo disable emmc swap...
        sed -i "s/^part = swap \(.*\)/#part = swap \1/" $PARTITION_TABLE
    fi

    return 0
}

function image_build()
{
    image_gen_version

    # use ANDROID_PRODUCT_OUT at image_file/components/bin/runCmd.pl
    android_product_out_dir_get ANDROID_PRODUCT_OUT

    build_cmd image_prepare
    ANDROID_VERSION=`get_android_major_version`
    if vmx_is_enable_boot_flow; then
        build_cmd vmx_image_update_partition_size
    elif [ $ANDROID_VERSION -le 7 ]; then
        build_cmd image_update_partition_size
    elif [ $ANDROID_VERSION -eq 8 ]; then
        build_cmd image_adjust_partition
    elif [ $ANDROID_VERSION -ge 9 ]; then
        build_cmd image_adjust_swap
    fi

    if [  $ANDROID_VERSION -ge 9 ] && [ "$IMAGE_INSTALL_DTB" = "1" ]; then
        echo IMAGE_INSTALL_DTB must be 0 in 9.0, clear it!
        config_set IMAGE_INSTALL_DTB 0
    fi

    config_get ANDROID_PRODUCT
    echo IMAGE_TARGET_CHIP=$IMAGE_TARGET_CHIP
    echo IMAGE_ADJ_VM=$IMAGE_ADJ_VM
    echo IMAGE_LAYOUT_TYPE=$IMAGE_LAYOUT_TYPE
    echo IMAGE_LAYOUT_SIZE=$IMAGE_LAYOUT_SIZE
    echo IMAGE_LAYOUT_USE_EMMC_SWAP=$IMAGE_LAYOUT_USE_EMMC_SWAP
    echo IMAGE_INSTALL_DTB=$IMAGE_INSTALL_DTB
    echo IMAGE_INSTALL_FACTORY=$IMAGE_INSTALL_FACTORY
    [ "$IMAGE_INSTALL_DTB" = "1" ] && echo IMAGE_TARGET_BOARD=$IMAGE_TARGET_BOARD

    make_parameters=
    list_add make_parameters image
    list_add make_parameters CHIP_ID=$IMAGE_TARGET_CHIP
    list_add make_parameters PACKAGES=$TARGET_PACKAGE
    list_add make_parameters install_dtb=$IMAGE_INSTALL_DTB
    if [ $ANDROID_VERSION -ge 8 ]; then
        list_add make_parameters GPT=1
        list_add make_parameters PART_RESIZE=1
    fi
    list_add make_parameters layout_type=$IMAGE_LAYOUT_TYPE
    list_add make_parameters layout_size=$IMAGE_LAYOUT_SIZE
    list_add make_parameters layout_use_emmc_swap=$IMAGE_LAYOUT_USE_EMMC_SWAP
    list_add make_parameters install_factory=$IMAGE_INSTALL_FACTORY
    list_add make_parameters AUDIOADDR=`firmware_begin_addr_get`
    list_add make_parameters ANDROID_PRODUCT=$ANDROID_PRODUCT

    if config_get_true IMAGE_RTK_BOOT_LOGO ; then
        list_add make_parameters install_avfile_count=1
    else
        list_add make_parameters install_avfile_count=0
    fi

    install_bootloader=0
    TEE_FW=n
    offline_gen=n
    image_is_install_bootloader 		&& install_bootloader=1
    image_tee_fw_is_enable      		&& TEE_FW=y
    image_is_offline_gen 			&& offline_gen=y
    list_add make_parameters install_bootloader=${install_bootloader}
    list_add make_parameters TEE_FW=${TEE_FW}
    list_add make_parameters offline_gen=${offline_gen}

    chip_rev=1
    config_get IMAGE_SECURE_CHIP_VERSION
    case "$IMAGE_TARGET_CHIP" in
        kylin)
            case "$IMAGE_CHIP_REVISION" in
                A00/A01)
                    chip_rev=1
                    ;;
                B00/B01)
                    chip_rev=2
                    ;;
            esac
            ;;
        hercules)
            case "$IMAGE_CHIP_REVISION" in
                A00)
                    chip_rev=1
                    ;;
                *)
                    chip_rev=2
                    ;;
            esac
            ;;
        thor)
            case "$IMAGE_CHIP_REVISION" in
                A00)
                    chip_rev=1
                    ;;
            esac
            ;;
    esac
    list_add make_parameters chip_rev=${chip_rev}
    list_add make_parameters SHRINK_GOLDEN_IMG=$SHRINK_GOLDEN_IMG
    list_add make_parameters MANIFEST_BRANCH=$MANIFEST_BRANCH
    list_add make_parameters TARGET_CHIP_ARCH=$TARGET_CHIP_ARCH

    if ! image_secure_type_is_off; then
        efuse_key=0
        efuse_fw=0
        FW_TABLE_SIGN=n
        DTB_ENC_IMG=n
        ENC_TA=n

        image_secure_is_efuse_key               && efuse_key=1
        image_secure_is_efuse_fw                && efuse_fw=1
        image_secure_is_fw_table_sign           && FW_TABLE_SIGN=y
        secure_func_dtb_enc_is_enable           && DTB_ENC_IMG=y
        image_secure_is_enc_ta                  && ENC_TA=y

        list_add make_parameters SECURE_BOOT=y
        list_add make_parameters efuse_key=${efuse_key}
        list_add make_parameters efuse_fw=${efuse_fw}
        list_add make_parameters FW_TABLE_SIGN=${FW_TABLE_SIGN}
        list_add make_parameters DTB_ENC=${DTB_ENC_IMG}
        list_add make_parameters ENC_TA=${ENC_TA}
    fi

    if image_enable_ab_system ; then
        list_add make_parameters enable_ab_system=y
    else
        list_add make_parameters enable_ab_system=n
    fi

    if secure_func_dmverity_is_enable && [ $ANDROID_VERSION -eq 8 ]; then
        list_add make_parameters enable_dm_verity=y
    else
        list_add make_parameters enable_dm_verity=n
    fi

    if vmx_is_enable_boot_flow; then
        vmx_install_mode=1
	vmx_test_mode=0

        config_get VMX_TYPE
        config_get VMX_INSTALL_MODE

        if [ "${VMX_TYPE}" == "ultra" ]; then
            case "$VMX_INSTALL_MODE" in
                trust_ota)
                    vmx_install_mode=0
                    ;;
                normal_ota)
                    vmx_install_mode=1
                    ;;
                rescue_ota)
                    vmx_install_mode=2
                    ;;
                trust_and_normal_ota)
                    vmx_install_mode=3
                    ;;
                trust_and_rescue_ota)
                    vmx_install_mode=4
                    ;;
                normal_and_rescue_ota)
                    vmx_install_mode=5
                    ;;
                full_ota)
                    vmx_install_mode=6
                    ;;
                full_install_image)
                    vmx_install_mode=6
                    ;;
            esac
        else
            case "$VMX_INSTALL_MODE" in
                rescue)
                    vmx_install_mode=0
                    ;;
                normal)
                    vmx_install_mode=1
                    ;;
                both)
                    vmx_install_mode=2
                    ;;
            esac
        fi

	vmx_test_mode_is_enable 		&& vmx_test_mode=1

	list_add make_parameters vmx=y
	list_add make_parameters vmx_install_mode=${vmx_install_mode}
	list_add make_parameters vmx_test_mode=${vmx_test_mode}

	list_add make_parameters vmx_type=${VMX_TYPE}

        if [ "${VMX_TYPE}" == "ultra" ] && [ "${VMX_INSTALL_MODE}" == "full_install_image" ]; then
            list_add make_parameters vmx_ultra_build_ota=no
            list_add make_parameters vmx_ultra_build_ota_with_oem_bootloader=no
        elif [ "${VMX_TYPE}" == "ultra" ]; then
            config_get VMX_OTA_WITH_OEM_BOOTLOADER
            list_add make_parameters vmx_ultra_build_ota=yes
            if [ "${VMX_OTA_WITH_OEM_BOOTLOADER}" == "true" ]; then
                list_add make_parameters vmx_ultra_build_ota_with_oem_bootloader=yes
            else
                list_add make_parameters vmx_ultra_build_ota_with_oem_bootloader=no
            fi
        fi
    else
        list_add make_parameters vmx=n
    fi

    pushd $IMAGEDIR > /dev/null
        echo make_parameters: $make_parameters
        make $make_parameters
        ERR=$?
    popd > /dev/null
    ls -l $IMAGEDIR/install.img
    return $ERR;
}

function image_clean()
{
    [ ! -d "$IMAGEDIR" ] && return 0
    local TARGET_PACKAGE=package5
    pushd $IMAGEDIR > /dev/null
    make clean PACKAGES=$TARGET_PACKAGE
    popd > /dev/null
}

function vmx_update_lk_bootloader_in_image()
{
    echo "backup $1, $2"
    [ -d $IMAGEDIR ] || return 0;
    image_config_prepare
    pushd $PACKAGE_DIR > /dev/null
    if vmx_is_enable_ultra; then
        cp $1 $PACKAGE_DIR/lk_ultra.bin
        cp $2 $PACKAGE_DIR/
        cp -f $PACKAGE_DIR/lk_ultra.bin $PACKAGE_DIR/rescue.lk_ultra.bin
    else
        cp $1 $PACKAGE_DIR/
        cp $2 $PACKAGE_DIR/
        cp -f $PACKAGE_DIR/lk.bin $PACKAGE_DIR/rescue.lk.bin
    fi
    popd
}
