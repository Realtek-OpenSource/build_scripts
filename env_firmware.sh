#!/bin/bash
[ "$ENV_FIRMWARE_SOURCE" != "" ] && return
ENV_FIRMWARE_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD

source $SCRIPTDIR/build_prepare.sh
source $SCRIPTDIR/env_platform.sh
source $SCRIPTDIR/env_rtksrc.sh

FIRMWARE_COMMON_SOURCE=`rtksrc_dir_get`/common
FIRMWARE_BRANCH=`rtksrc_dir_get`/audio/src/Integrated
FIRMWARE_IMAGE_OUT=$FIRMWARE_BRANCH/project/dvr_audio
FIRMWARE_MAKE=$FIRMWARE_BRANCH/src

function firmware_export_version_get()
{
    version=

    if [ -d "$FIRMWARE_BRANCH" ]; then
        pushd $FIRMWARE_BRANCH > /dev/null

            if [ "$FIRMWARE_CHECKOUT_BRANCH" == "TrunkBranch" ] || [ "$FIRMWARE_CHECKOUT_BRANCH" == "CustBranch" ]; then
                version=`git log --pretty=format:'%h' -n 1`
            else
                #version=`LANGUAGE=en_US.en svn info|grep Revision|awk '{print $2}'`
                version=`LANGUAGE=en_US.en svn info|grep 'Last Changed Rev'|awk '{print $4}'`
            fi
        popd > /dev/null
    else
        version="N/A"
    fi

    [ "$1" != "" ] && export $1=${version} || echo ${version}
    return 0
}

function firmware_image_get()
{
    item=$1
    FIRMWARE_IMAGE=bluecore.audio
    FILE=${FIRMWARE_IMAGE_OUT}/${FIRMWARE_IMAGE}
    if [ ! -e "$FILE" ]; then
        [ "$item" != "" ] && export ${item}=""
        return 1
    fi
    [ "$item" != "" ] && export ${item}="${FILE}" || echo $FILE
    return 0
}

function firmware_image_map_get()
{
    item=$1
    FIRMWARE_MAP=System.map.audio
    FILE=${FIRMWARE_IMAGE_OUT}/${FIRMWARE_MAP}
    if [ ! -e "$FILE" ]; then
        [ "$item" != "" ] && export ${item}=""
        return 1
    fi
    [ "$item" != "" ] && export ${item}="${FILE}" || echo $FILE
    return 0
}

function firmware_image_zip_get()
{
    item=$1
    FIRMWARE_ZIP=bluecore.audio.zip
    FILE=${FIRMWARE_IMAGE_OUT}/${FIRMWARE_ZIP}
    if [ ! -e "$FILE" ]; then
        [ "$item" != "" ] && export ${item}=""
        return 1
    fi
    [ "$item" != "" ] && export ${item}="${FILE}" || echo $FILE
    return 0
}

function firmware_begin_addr_get()
{
    config_get FIRMWARE_TARGET_CHIP
    config_get FIRMWARE_SUBVERSION
    item=$1
    FIRMWARE_ADDR=
    case "$FIRMWARE_TARGET_CHIP" in
        phoenix)
            FIRMWARE_ADDR="0x01b00000"
            ;;
        kylin)
            case "$FIRMWARE_SUBVERSION" in
                release_160705_81b00000.SQA | release_160705_CVBS_on_81b00000.SQA | release.SQA | release_CVBS_on.SQA )
                    FIRMWARE_ADDR="0x01b00000"
                    ;;
                *)
                    FIRMWARE_ADDR="0x0f900000"
                    ;;
            esac
            ;;
        hercules)
            FIRMWARE_ADDR="0x0f900000"
            ;;
        thor)
            FIRMWARE_ADDR="0x0f900000"
            ;;
        *)
            FIRMWARE_ADDR="0x0f900000"
            ;;
    esac
    [ "$item" != "" ] && export ${item}="${FIRMWARE_ADDR}" || echo $FIRMWARE_ADDR
    return 0
}

function firmware_init()
{
    rtksrc_init
    return $?
}

function firmware_config()
{
    FIRMWARE_TARGET_CHIP_LIST=
    list_add FIRMWARE_TARGET_CHIP_LIST phoenix
    list_add FIRMWARE_TARGET_CHIP_LIST kylin
    list_add FIRMWARE_TARGET_CHIP_LIST hercules
    list_add FIRMWARE_TARGET_CHIP_LIST thor
    config_get_menu FIRMWARE_TARGET_CHIP FIRMWARE_TARGET_CHIP_LIST phoenix
    case "$FIRMWARE_TARGET_CHIP" in
        phoenix)
            FIRMWARE_SUBVERSION_LIST=
            list_add FIRMWARE_SUBVERSION_LIST debug_150922.SQA
            list_add FIRMWARE_SUBVERSION_LIST debug.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_150922_Primax.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_150922.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_LVDS_1280_800.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_LVDS_1920_1080_PORT_AB.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_LVDS_800_480_PORT_A6BIT.SQA
            list_add FIRMWARE_SUBVERSION_LIST release.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_SUNNIWELL.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_ZTE.SQA
	    list_add FIRMWARE_SUBVERSION_LIST release_150922_INNOPIA_M534.SQA
	    list_add FIRMWARE_SUBVERSION_LIST release_150922_ActionMicro_8271.SQA
	    list_add FIRMWARE_SUBVERSION_LIST release_150922_ActionMicro.SQA
            config_get_menu FIRMWARE_SUBVERSION FIRMWARE_SUBVERSION_LIST release_150922.SQA
            ;;
        kylin)
            FIRMWARE_SUBVERSION_LIST=
            list_add FIRMWARE_SUBVERSION_LIST debug_160705.SQA
            list_add FIRMWARE_SUBVERSION_LIST debug.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_160705_81b00000.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_160705_CVBS_on_81b00000.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_160705_CVBS_on.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_160705.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_CVBS_on.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_NAS_slim.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_NAS_slim_disable_vo.SQA
            list_add FIRMWARE_SUBVERSION_LIST release.SQA
            FIRMWARE_SUBVERSION_LIST_DEFAULT=release_160705.SQA
            case "$BRANCH_QA_TARGET" in
                CustBranch-QA160627 | CustBranch-QA160627-b/CustBranch-QA160627-nuplayer-2016-11-17)
                    FIRMWARE_SUBVERSION_LIST_DEFAULT=release.SQA
                    ;;
		trunk-7.0-b/QA170823-b/ZINWELL-KOD-TAG-QA170823_Kylin_2017-09-26)
                    FIRMWARE_SUBVERSION_LIST_DEFAULT=release_160705.SQA
                    ;;
            esac
            config_get_menu FIRMWARE_SUBVERSION FIRMWARE_SUBVERSION_LIST $FIRMWARE_SUBVERSION_LIST_DEFAULT
            ;;
        hercules)
            FIRMWARE_SUBVERSION_LIST=
            list_add FIRMWARE_SUBVERSION_LIST release.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_SecureFWRPC.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_PAPER_MULBERRY.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_slim.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_slim_disable_vo.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_SecureFWRPC_1G.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_SecureFWRPC_DMX.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_SecureFWRPC_CVBS_DMX.SQA
            config_get_menu FIRMWARE_SUBVERSION FIRMWARE_SUBVERSION_LIST release.SQA
            ;;
        thor)
            FIRMWARE_SUBVERSION_LIST=
            list_add FIRMWARE_SUBVERSION_LIST release.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_SecureFWRPC.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_slim.SQA
            list_add FIRMWARE_SUBVERSION_LIST release_slim_disable_vo.SQA
            config_get_menu FIRMWARE_SUBVERSION FIRMWARE_SUBVERSION_LIST release.SQA
            ;;
    esac

    FIRMWARE_MKCONFIG_MAIN=MakeConfig.${FIRMWARE_TARGET_CHIP}_${FIRMWARE_SUBVERSION}
    config_get FIRMWARE_MKCONFIG
    if [ "$?" != "0" ] || [ "$FIRMWARE_MKCONFIG" != "${FIRMWARE_MKCONFIG_MAIN}" ]; then
        config_set FIRMWARE_MKCONFIG ${FIRMWARE_MKCONFIG_MAIN}
    fi
    return 0
}

function firmware_checkout_config()
{
    FIRMWARE_CHECKOUT_BRANCH_LIST=
    list_add FIRMWARE_CHECKOUT_BRANCH_LIST CustBranch
    list_add FIRMWARE_CHECKOUT_BRANCH_LIST QA170623_SKBroadband-XEN
    list_add FIRMWARE_CHECKOUT_BRANCH_LIST ZINWELL-KOD-TAG-QA170823_Kylin_2017-09-26
    list_add FIRMWARE_CHECKOUT_BRANCH_LIST TrunkBranch
    list_add FIRMWARE_CHECKOUT_BRANCH_LIST PhoenixBranch
    case "$BRANCH_QA_TARGET" in
        CustBranch-QA160627 | CustBranch-QA160627-b/CustBranch-QA160627-nuplayer-2016-11-17)
            FIRMWARE_CHECKOUT_BRANCH_LIST_DEFAULT=CustBranch
            ;;
        trunk-7.0-b/QA170623-b/QA170623_SKBroadband-XEN)
            FIRMWARE_CHECKOUT_BRANCH_LIST_DEFAULT=QA170623_SKBroadband-XEN
            ;;
	trunk-7.0-b/QA170823-b/ZINWELL-KOD-TAG-QA170823_Kylin_2017-09-26)
            FIRMWARE_CHECKOUT_BRANCH_LIST_DEFAULT=QA170823_KOD
            ;;
        *)
            FIRMWARE_CHECKOUT_BRANCH_LIST_DEFAULT=TrunkBranch
            ;;
    esac
    case "$FIRMWARE_TARGET_CHIP" in
        phoenix)
            FIRMWARE_CHECKOUT_BRANCH_LIST_DEFAULT=PhoenixBranch
            ;;
    esac
    config_get_menu FIRMWARE_CHECKOUT_BRANCH FIRMWARE_CHECKOUT_BRANCH_LIST $FIRMWARE_CHECKOUT_BRANCH_LIST_DEFAULT

    return 0
}

function firmware_checkout()
{
    firmware_checkout_config
    platform_checkout && rtksrc_checkout || return 1
    if [ ! -e "$FIRMWARE_BRANCH" ]; then
        mkdir -p $FIRMWARE_BRANCH
        pushd $FIRMWARE_BRANCH > /dev/null
        config_get GERRIT_SERVER
        git_url=
        svn_url=
            case "$FIRMWARE_CHECKOUT_BRANCH" in
                CustBranch)
                    #svn_url=svn/CN/CNDOC/trunk/CNDOC/DHCDOC/OTT/branches/Kylin/software_branches/Integrated_CustBranch-QA160627
                    git_url=${GERRIT_SERVER}/avfw/kylin/audio/src/Integrated_CustBranch-QA160627
                    ;;
		QA170623_SKBroadband-XEN)
		    svn_url=svn/CN/CNDOC/trunk/CNDOC/DHCDOC/OTT/branches/Kylin/software_branches/Integrated_QA170623_SKBroadband-XEN
		    ;;
		ZINWELL-KOD-TAG-QA170823_Kylin_2017-09-26)
		    svn_url=svn/CN/CNDOC/trunk/CNDOC/DHCDOC/OTT/branches/Kylin/software_branches/Integrated_QA170823_KOD
		    ;;
		PhoenixBranch)
		    git_url=${GERRIT_SERVER}/avfw/phoenix/audio/src/Integrated
                    ;;
                TrunkBranch | * )
                    #svn_url=svn/CN/CNDOC/trunk/CNDOC/DHCDOC/OTT/trunk/software/audio/src/Integrated
                    git_url=${GERRIT_SERVER}/avfw/audio/src/Integrated
                    ;;
            esac
            if [ "$git_url" != "" ]; then
                git clone ${git_url} .
            else
                svn co http://${SVN_SERVER}/${svn_url} .
            fi
            ERR=$?
        popd > /dev/null
	else
		echo "$FIRMWARE_BRANCH is already existed, please remove it or sync it?"
        ERR=0
    fi
    return $ERR
}

function firmware_check_toolchain()
{
    TOOLCHAINNAME=rsdk-1.5.5
    if ! platform_toolchain_checkout $TOOLCHAINNAME FW_TOOLCHAINDIR ; then
        echo "firmware toolchain ($TOOLCHAINNAME) checkout failed!"
        return 1
    fi

    FW_TOOLCHAINDIR=${FW_TOOLCHAINDIR}/linux/newlib/bin
    if [ ! -d "$FW_TOOLCHAINDIR" ]; then
        echo "firmware toolchain dir ($FW_TOOLCHAINDIR) not found!"
        return 2
    fi

    export PATH=$FW_TOOLCHAINDIR:$PATH
    return 0
}

function firmware_build()
{
    config_get FIRMWARE_TARGET_CHIP     || (echo "[err] should config chip type";       return 1)
    config_get FIRMWARE_MKCONFIG        || (echo "[err] should config the build type";  return 2)
    FIRMWARE_MKCONFIG_FILE=${FIRMWARE_MAKE}/MkCfgSQA/${FIRMWARE_TARGET_CHIP}/${FIRMWARE_MKCONFIG}
    [ ! -e "${FIRMWARE_MKCONFIG_FILE}" ] || (echo "[err] config file not found!($FIRMWARE_MKCONFIG_FILE)" ; return 3)

    firmware_check_toolchain || return 4

    build_cmd rtksrc_build_prepare

    pushd $FIRMWARE_COMMON_SOURCE
        if [ $FIRMWARE_TARGET_CHIP == "phoenix" ]; then
            git checkout remotes/origin/master_1195
        fi
	make
	ERR=$?
    popd

    pushd $FIRMWARE_MAKE
        cp ${FIRMWARE_MKCONFIG_FILE} MakeConfig
        make all
        ERR=$?
    popd
    return $ERR
}

function firmware_sync()
{
    if [ -d "$FIRMWARE_BRANCH" ]; then
        pushd $FIRMWARE_BRANCH
            if [ "$FIRMWARE_CHECKOUT_BRANCH" == "TrunkBranch" ] || [ "$FIRMWARE_CHECKOUT_BRANCH" == "CustBranch" ]; then
                git pull
            else
                svn up
            fi
        ERR=$?
        popd > /dev/null
    fi

    [ "$ERR" != "0" ] && return $ERR

    if [ -d "$FIRMWARE_COMMON_SOURCE" ]; then
        pushd $FIRMWARE_COMMON_SOURCE
        repo sync --force-sync .
        ERR=$?
        popd > /dev/null
    fi

    [ "$ERR" != "0" ] && return $ERR

    rtksrc_sync
    ERR=$?

    return $ERR
}

function firmware_clean()
{
    [ ! -d "$FIRMWARE_BRANCH" ] && return 1
    pushd $FIRMWARE_MAKE
        make clean
        ERR=$?
    popd
    return $ERR
}
