#!/bin/bash
[ "$ENV_VMX_SOURCE" != "" ] && return

ENV_VMX_SOURCE=1
IMAGEDIR=$TOPDIR/image_file

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh

function vmx_config()
{
    config_get_bool VMX_CONFIG false
    config_get_false VMX_RELEASE_MODE || config_set VMX_RELEASE_MODE false
    if [ "$VMX_CONFIG" = "true" ]; then
		#config_get_true ENABLE_VMX_DRM || config_set ENABLE_VMX_DRM true
		vmx_client_config
	config_get_bool VMX_HARDENING false
        VMX_BOOT_LIST=
        list_add VMX_BOOT_LIST normal_boot
        list_add VMX_BOOT_LIST vmx_boot
        config_get_menu VMX_BOOT_OPTION VMX_BOOT_LIST normal_boot

        case "$VMX_BOOT_OPTION" in
            normal_boot)
                config_get_false ENABLE_VMX_BOOT_FLOW || config_set ENABLE_VMX_BOOT_FLOW false
                ;;
            vmx_boot)
                config_get_true ENABLE_VMX_BOOT_FLOW || config_set ENABLE_VMX_BOOT_FLOW true
                ;;
        esac

        config_get KERNEL_TARGET_CHIP
        config_get ANDROID_PRODUCT
        if [ "$KERNEL_TARGET_CHIP" = "hercules" ] || [ ${ANDROID_PRODUCT:0:12} = "rtk_hercules" ]; then
            config_set VMX_TYPE ultra
        elif [ "$KERNEL_TARGET_CHIP" = "kylin" ] || [ ${ANDROID_PRODUCT:0:9} = "rtk_kylin" ]; then
            config_set VMX_TYPE advance
        else
            VMX_TYPE_LIST=
            list_add VMX_TYPE_LIST advance
            list_add VMX_TYPE_LIST ultra
            config_get_menu VMX_TYPE VMX_TYPE_LIST advance

            case "$VMX_TYPE" in
               advance)
                    config_set VMX_TYPE advance
                    ;;
               ultra)
                    config_set VMX_TYPE ultra
                    ;;
            esac
        fi

        VMX_INSTALL_MODE_LIST=
	if [ ${VMX_TYPE} == "ultra" ]; then
	    list_add VMX_INSTALL_MODE_LIST trust_ota
            list_add VMX_INSTALL_MODE_LIST normal_ota
            list_add VMX_INSTALL_MODE_LIST rescue_ota
            list_add VMX_INSTALL_MODE_LIST trust_and_normal_ota
            list_add VMX_INSTALL_MODE_LIST trust_and_rescue_ota
            list_add VMX_INSTALL_MODE_LIST normal_and_rescue_ota
            list_add VMX_INSTALL_MODE_LIST full_ota
            list_add VMX_INSTALL_MODE_LIST full_install_image
            config_get_menu VMX_INSTALL_MODE VMX_INSTALL_MODE_LIST full_install_image

            if [ ${VMX_INSTALL_MODE} != "full_install_image" ]; then
                config_get_bool VMX_OTA_WITH_OEM_BOOTLOADER false
                if [ ${VMX_OTA_WITH_OEM_BOOTLOADER} = "true" ] && [ ! -e "$IMAGEDIR/components/packages/package5/oem_bootloader.bin" ]; then
                    echo NO oem_bootloader.bin found at image_file folder, exit.
                    exit 1
                fi
            fi
	else
            list_add VMX_INSTALL_MODE_LIST rescue
            list_add VMX_INSTALL_MODE_LIST normal
            list_add VMX_INSTALL_MODE_LIST both
            config_get_menu VMX_INSTALL_MODE VMX_INSTALL_MODE_LIST normal
	fi
		config_get_bool VMX_TEST_MODE false
    else
		vmx_disable_dvb_config
    fi
}

function vmx_disable_dvb_config()
{
	config_remove USE_VMX_DEMO_APK
	config_remove USE_VMX_RTK_EXTRACTOR_CONTROL
	config_remove ENABLE_VMX_CA_CONTROL
	config_remove VMX_RELEASE_MODE 
	config_remove VMX_BOOT_OPTION
	config_remove ENABLE_VMX_BOOT_FLOW
	config_remove VMX_INSTALL_MODE
	config_remove VMX_TEST_MODE
	config_remove USE_VMX_DVB_CLIENT
	config_remove USE_VMX_IPTV_CLIENT
	config_remove USE_VMX_WEB_CLIENT
	config_remove VMX_OTA_WITH_OEM_BOOTLOADER
}

function vmx_client_config()
{
	VMX_CLIENT_LIST=
	list_add VMX_CLIENT_LIST vmx_dvb
	list_add VMX_CLIENT_LIST vmx_iptv
	list_add VMX_CLIENT_LIST vmx_web
	list_add VMX_CLIENT_LIST none
	
	config_get_menu VMX_CLIENT_OPTION VMX_CLIENT_LIST vmx_dvb
	
	case "$VMX_CLIENT_OPTION" in 
		vmx_dvb)
			config_get_true USE_VMX_DVB_CLIENT || config_set USE_VMX_DVB_CLIENT true
			config_get_true USE_VMX_DEMO_APK || config_set USE_VMX_DEMO_APK true
        	config_get_false USE_VMX_RTK_EXTRACTOR_CONTROL || config_set USE_VMX_RTK_EXTRACTOR_CONTROL false
        	#config_get_true ENABLE_VMX_CA_CONTROL || config_set ENABLE_VMX_CA_CONTROL true
			config_get_true ENABLE_VMX_DRM  || config_set ENABLE_VMX_DRM true
			config_remove USE_VMX_IPTV_CLIENT
			config_remove USE_VMX_WEB_CLIENT
			;;
		vmx_iptv)
			config_get_true USE_VMX_IPTV_CLIENT || config_set USE_VMX_IPTV_CLIENT true
			config_get_true ENABLE_VMX_DRM  || config_set ENABLE_VMX_DRM true
			config_remove USE_VMX_DEMO_APK
			config_remove USE_VMX_RTK_EXTRACTOR_CONTROL
			#config_remove ENABLE_VMX_CA_CONTROL
			config_remove USE_VMX_DVB_CLIENT
			config_remove USE_VMX_WEB_CLIENT
			;;
		
		vmx_web)
			config_get_true USE_VMX_WEB_CLIENT || config_set USE_VMX_WEB_CLIENT true
			config_get_true ENABLE_VMX_DRM  || config_set ENABLE_VMX_DRM true
			config_remove USE_VMX_IPTV_CLIENT
			config_remove USE_VMX_DEMO_APK
			config_remove USE_VMX_RTK_EXTRACTOR_CONTROL
			#config_remove ENABLE_VMX_CA_CONTROL
			config_remove USE_VMX_DVB_CLIENT
			config_remove USE_VMX_IPTV_CLIENT
		;;
		none)
			config_remove USE_VMX_IPTV_CLIENT
			config_remove USE_VMX_DEMO_APK
			config_remove USE_VMX_RTK_EXTRACTOR_CONTROL
			#config_remove ENABLE_VMX_CA_CONTROL
			config_remove USE_VMX_DVB_CLIENT
			config_remove USE_VMX_IPTV_CLIENT
			config_remove USE_VMX_WEB_CLIENT
			config_remove USE_VMX_DRM
		;;
		
	esac
}

function vmx_is_drm_enable()
{
	config_get ENABLE_VMX_DRM
	[ "$ENABLE_VMX_DRM" = "true" ] && return 0 || return 1
	
}
function vmx_is_iptv_client()
{
	config_get USE_VMX_IPTV_CLIENT
    [ "$USE_VMX_IPTV_CLIENT" = "true" ] && return 0 || return 1
}

function vmx_is_web_client()
{
	config_get USE_VMX_WEB_CLIENT
    [ "$USE_VMX_WEB_CLIENT" = "true" ] && return 0 || return 1
}

function vmx_is_dvb_client()
{
	config_get USE_VMX_DVB_CLIENT
    [ "$USE_VMX_DVB_CLIENT" = "true" ] && return 0 || return 1
}

function vmx_is_use_rtk_extractor()
{
    config_get USE_VMX_RTK_EXTRACTOR_CONTROL
    [ "$USE_VMX_RTK_EXTRACTOR_CONTROL" = "true" ] && return 0 || return 1
}

function vmx_is_use_vmx_apk()
{
    config_get USE_VMX_DEMO_APK
    [ "$USE_VMX_DEMO_APK" = "true" ] && return 0 || return 1
}

#function vmx_is_enable_ca_control()
#{
#    config_get ENABLE_VMX_CA_CONTROL
#   [ "$ENABLE_VMX_CA_CONTROL" = "true" ] && return 0 || return 1
#}

function vmx_is_in_release_mode()
{
    config_get VMX_RELEASE_MODE
    [ "$VMX_RELEASE_MODE" = "true" ] && return 0 || return 1
}

function vmx_is_enable_boot_flow()
{
    config_get ENABLE_VMX_BOOT_FLOW
    [ "$ENABLE_VMX_BOOT_FLOW" = "true" ] && return 0 || return 1
}

function vmx_dvdplayer_name_get()
{
	if vmx_is_iptv_client ;then
		CLIENT_TYPE=.IPTV
	elif vmx_is_dvb_client ; then
		CLIENT_TYPE=.DVB
	elif vmx_is_web_client ; then
		CLIENT_TYPE=.WEB
	fi
	
	if drm_type_is_with_svp ; then
		DVD_BIN=DvdPlayer$CLIENT_TYPE.SVP
	else
		DVD_BIN=DvdPlayer$CLIENT_TYPE
	fi
    
    [ "$1" != "" ] && export $1=${DVD_BIN} || echo ${DVD_BIN}
    return 0
}

function vmx_is_enable_ultra()
{
    config_get VMX_TYPE
    [ "$VMX_TYPE" = "ultra" ] && return 0 || return 1
}

function vmx_ca_environment()
{
    SYSTEMDIR=${SCRIPTDIR}/software_Phoenix_RTK/system
    PACKAGE=package5
    QA_SUPPLEMENT=${SCRIPTDIR}/qa_supplement/vmx
    TARGET_DIR=${SCRIPTDIR}/image_file/components/packages/${PACKAGE}/
    ANDROID_VENDOR_DIR=`android_vendor_dir_get`
    ANDROID_SYSTEM_DIR=`android_system_dir_get`
    mkdir -p ${ANDROID_VENDOR_DIR}/lib/teetz
	
    #cp -rf ${SYSTEMDIR}/src/Unit_test/AndroidDvdPlayer/DvdPlayer `image_daily_build_dir_get`/${PACKAGE}/system/bin/
	cp -rfv ${SYSTEMDIR}/src/Unit_test/AndroidDvdPlayer/`vmx_dvdplayer_name_get` `image_daily_build_dir_get`/${PACKAGE}/system/bin/DvdPlayer
		
	
    config_get KERNEL_TARGET_CHIP
    #cp -rf ${QA_SUPPLEMENT}/${KERNEL_TARGET_CHIP}/system/lib/teetz/internal/*.ta* ${ANDROID_SYSTEM_DIR}/lib/teetz/
    cp -rf ${QA_SUPPLEMENT}/${KERNEL_TARGET_CHIP}/system/lib/libteec.so  ${ANDROID_SYSTEM_DIR}/lib/
    cp -rf ${QA_SUPPLEMENT}/${KERNEL_TARGET_CHIP}/system/bin/tee-supplicant ${ANDROID_SYSTEM_DIR}/bin/
    rsync -a ${QA_SUPPLEMENT}/${KERNEL_TARGET_CHIP}/system/lib/teetz/internal/*.ta*      ${ANDROID_VENDOR_DIR}/lib/teetz/

    # ULTRA BOOT
    if vmx_is_enable_boot_flow && vmx_is_enable_ultra; then
        #cp -rf ${QA_SUPPLEMENT}/${KERNEL_TARGET_CHIP}/system/lib/teetz/release/*.ta* ${ANDROID_SYSTEM_DIR}/lib/teetz/
	rsync -a ${QA_SUPPLEMENT}/${KERNEL_TARGET_CHIP}/system/lib/teetz/release/*.ta* ${ANDROID_VENDOR_DIR}/lib/teetz/
    fi

   
	
}

function vmx_test_mode_is_enable()
{
    config_get VMX_TEST_MODE
    [ "$VMX_TEST_MODE" = "true" ] && return 0 || return 1
}

function vmx_config_is_enable()
{
    config_get VMX_CONFIG
    [ "$VMX_CONFIG" = "true" ] && return 0 || return 1
}

function vmx_hardening_is_enable()
{
    config_get VMX_HARDENING
    [ "$VMX_HARDENING" = "true" ] && return 0 || return 1
}

function vmx_image_update_partition_size()
{
    config_get ANDROID_PRODUCT

    ANDROID_SYSTEM=`android_system_dir_get`
    SYSTEM_SIZE=`du -sm $ANDROID_SYSTEM | cut -f 1` #in MB

    if [ "$IMAGE_LAYOUT_SIZE" == "4gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc
    elif [ "$IMAGE_LAYOUT_SIZE" == "8gb" ]; then
        LAYOUT_DIR=rtk_generic_emmc_8gb
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
        ADDITIONAL_DATA_REDUCTION=0
    else
        ADDITIONAL_DATA_REDUCTION=$((300 * 1024 * 1024))
    fi
    if [ "$VND_PARTSIZE" == "" ]; then
        VND_PARTSIZE=0 #vendor partition is commented out for now
    fi
    AVAIL_SPACE=$(($SYS_PARTSIZE + $DAT_PARTSIZE + $VND_PARTSIZE))
    echo available space is $AVAIL_SPACE

    DAT_PARTSIZE=$(($AVAIL_SPACE - $ADDITIONAL_DATA_REDUCTION))
    echo adjust data partition size to $(($DAT_PARTSIZE / 1024 / 1024))MB
    sed -i "s/^part = data \(.*\) \(.*\) \(.*\) \(.*\)/part = data \1 \2 \3 $DAT_PARTSIZE/" $PARTITION_TABLE

    # resize logo partition to 40MB
    LOGO_PARTSIZE=$((40 * 1024 * 1024))
    echo adjust logo partition size to $(($LOGO_PARTSIZE / 1024 / 1024))MB
    sed -i "s/^part = logo \(.*\) \(.*\) \(.*\) \(.*\)/part = logo \1 \2 \3 $LOGO_PARTSIZE/" $PARTITION_TABLE

    # comment system partition
    sed -i "s/^part = system \(.*\)/#part = system \1/" $PARTITION_TABLE
    # comment vendor partition
    sed -i "s/^part = vendor \(.*\)/#part = vendor \1/" $PARTITION_TABLE
    # comment uboot partition
    sed -i "s/^part = uboot \(.*\)/#part = uboot \1/" $PARTITION_TABLE
    # comment backup partition
    sed -i "s/^part = backup \(.*\)/#part = backup \1/" $PARTITION_TABLE
    # comment verify partition
    sed -i "s/^part = verify \(.*\)/#part = verify \1/" $PARTITION_TABLE

    # un-comment install partition
    if [ ${ANDROID_PRODUCT:0:8} != "hercules" ]; then
        sed -i "s/#part = install \(.*\)/part = install \1/" $PARTITION_TABLE
    fi;

    return 0
}
