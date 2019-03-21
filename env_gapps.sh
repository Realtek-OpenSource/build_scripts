#!/bin/bash

[ "$ENV_GAPPS_SOURCE" != "" ] && return
ENV_GAPPS_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
source $SCRIPTDIR/env_qa_sub.sh
source $SCRIPTDIR/env_android.sh

function gapps_checkout()
{
    gapps_type_is_off && return 0
    qa_sub_checkout
    return $?
}

function gapps_sync()
{
    gapps_type_is_off && return 0
    qa_sub_sync
    return $?
}

function gapps_config()
{
    GAPPS_OPTION_LIST=
    list_add GAPPS_OPTION_LIST tv
    list_add GAPPS_OPTION_LIST tablet
    list_add GAPPS_OPTION_LIST off
    config_get_menu     GAPPS_OPTION    GAPPS_OPTION_LIST   off
}

function gapps_type_is_off()
{
    config_get GAPPS_OPTION || gapps_config
    [ "$GAPPS_OPTION" = "off" ] && return 0 || return 1
}

function gapps_type_is_tv()
{
    config_get GAPPS_OPTION || gapps_config
    [ "$GAPPS_OPTION" = "tv" ] && return 0 || return 1
}

function gapps_type_is_tablet()
{
    config_get GAPPS_OPTION || gapps_config
    [ "$GAPPS_OPTION" = "tablet" ] && return 0 || return 1
}

function gapps_clean_file_check()
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

export -f gapps_clean_file_check

function gapps_setup_system_by_tv()
{
    system_dir=$1
    [ -e "$system_dir" ] || return 1
    qa_sub_dir_get QA_SUPDIR
    echo copy tv gapps
    if [ -d $QA_SUPDIR/tv ]; then # new file structure for 7.0
        rsync -a $QA_SUPDIR/tv/system/* ${system_dir}
        [ -d $QA_SUPDIR/tv/system/priv-app/GooglePackageInstaller ] && rm -rf ${system_dir}/priv-app/PackageInstaller
        [ -d $QA_SUPDIR/tv/system/priv-app/SetupWraith ] && rm -rf ${system_dir}/priv-app/Provision
        [ -d $QA_SUPDIR/tv/system/app/GoogleTTS ] && rm -rf ${system_dir}/app/PicoTts

        #workaround for bluetooth.apk
        [ -d $QA_SUPDIR/tv/system/priv-app/GamepadPairingService ] && rm -rf ${system_dir}/priv-app/GamepadPairingService
    else                          # old file structure for 5.0 & 6.0
        [ -d $QA_SUPDIR/gapps  ] && rsync -a $QA_SUPDIR/gapps/system/* ${system_dir}
        [ -d $QA_SUPDIR/gms/tv ] && rsync -a $QA_SUPDIR/gms/tv/system/* ${system_dir}
        [ -d $QA_SUPDIR/addons ] && rsync -a $QA_SUPDIR/addons/system/* ${system_dir}
    fi
    return 0
}

function gapps_clean_system_by_tv()
{
    system_dir=$1
    [ -e "$system_dir" ] || return 1
    qa_sub_dir_get QA_SUPDIR
    echo clean tv gapps
    if [ -d $QA_SUPDIR/tv ]; then # new file structure for 7.0
        pushd $QA_SUPDIR/tv/system/ > /dev/null
            find . -type f | xargs -i echo {} ${system_dir}/{}| xargs -i bash -c 'gapps_clean_file_check {}'
        popd > /dev/null
    else
        COPY_SYSTEM_LIST=
        list_add COPY_SYSTEM_LIST $QA_SUPDIR/gapps/system
        list_add COPY_SYSTEM_LIST $QA_SUPDIR/gms/tv/system
        list_add COPY_SYSTEM_LIST $QA_SUPDIR/addons/system
        for d in $COPY_SYSTEM_LIST
        do
            if [ -d "$d" ]; then
                pushd $d > /dev/null
                    find . -type f | xargs -i echo {} ${system_dir}/{}| xargs -i bash -c 'gapps_clean_file_check {}'
                popd > /dev/null
            fi
        done
    fi
}

function gapps_setup_system_by_tablet()
{
    system_dir=$1
    [ -e "$system_dir" ] || return 1
    qa_sub_dir_get QA_SUPDIR
    echo copy tablet gapps
    if [ -d $QA_SUPDIR/tablet ]; then # new file structure for 7.0
        rsync -a $QA_SUPDIR/tablet/system/* ${system_dir}
        [ -d $QA_SUPDIR/tablet/system/priv-app/GooglePackageInstaller ] && rm -rf ${system_dir}/priv-app/PackageInstaller
        [ -d $QA_SUPDIR/tablet/system/priv-app/SetupWizard ] && rm -rf ${system_dir}/priv-app/Provision
        [ -d $QA_SUPDIR/tablet/system/app/GoogleTTS ] && rm -rf ${system_dir}/app/PicoTts
    else                              # old file structure for 5.0 & 6.0
        [ -d $QA_SUPDIR/gapps  ] && rsync -a $QA_SUPDIR/gapps/system/* ${system_dir}
        [ -d $QA_SUPDIR/gms/tablet ] && rsync -a $QA_SUPDIR/gms/tablet/system/* ${system_dir}
    fi
    return 0
}

function gapps_clean_system_by_tablet()
{
    system_dir=$1
    [ -e "$system_dir" ] || return 1
    qa_sub_dir_get QA_SUPDIR
    echo clean tablet gapps
    if [ -d $QA_SUPDIR/tablet ]; then # new file structure for 7.0
        pushd $QA_SUPDIR/tablet/system > /dev/null
            find . -type f | xargs -i echo {} ${system_dir}/{}| xargs -i bash -c 'gapps_clean_file_check {}'
        popd > /dev/null
    else
        COPY_SYSTEM_LIST=
        list_add COPY_SYSTEM_LIST $QA_SUPDIR/gapps/system
        list_add COPY_SYSTEM_LIST $QA_SUPDIR/gms/tablet/system
        for d in $COPY_SYSTEM_LIST
        do
            if [ -d "$d" ]; then
                pushd $d > /dev/null
                    find . -type f | xargs -i echo {} ${system_dir}/{}| xargs -i bash -c 'gapps_clean_file_check {}'
                popd > /dev/null
            fi
        done
    fi
    return 0
}

function gapps_setup_system()
{
    system_dir=`android_system_dir_get`
    [ -e "$system_dir" ] || return 0
    gapps_type_is_off       && return 0
    gapps_type_is_tv        && (gapps_setup_system_by_tv ${system_dir}     ;return $?)
    gapps_type_is_tablet    && (gapps_setup_system_by_tablet ${system_dir} ;return $?)
}

function gapps_clean_system()
{
    system_dir=`android_system_dir_get`

    [ -e "$system_dir" ] || return 0
    gapps_type_is_off && [ ! -d "`qa_sub_dir_get`" ] && return 0

    if gapps_type_is_off ; then
        gapps_clean_system_by_tv ${system_dir} || return 1
        gapps_clean_system_by_tablet ${system_dir} || return 2
    elif gapps_type_is_tv ; then
        gapps_clean_system_by_tablet ${system_dir} || return 3
    elif gapps_type_is_tablet ; then
        gapps_clean_system_by_tv ${system_dir} || return 4
    else
        return 5
    fi
    return 0
}
