#!/bin/bash
[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh

source $SCRIPTDIR/env_android.sh    get_parameters

ERR=0

# set umask here to prevent incorrect file permission
umask 0022

function android_usage()
{
    echo "$0 commands are:"
    echo "    config    "
    echo "    checkout    "
    #echo "    clean       "
    echo "    sync        "
    echo "    build       "
    echo "    otapackage  "
    echo "    update-api  "
}

function android_command()
{
    while [ "$1" != "" ]
    do
        case "$1" in
            init)
                android_init
                ;;
            config)
                android_config
                ;;
            checkout)
                build_cmd android_checkout
                ;;
            build)
                build_cmd android_build
		build_cmd ln_libOMX_realtek
                ;;
            otapackage)
                build_cmd android_build_otapackage
                ;;
            sync)
                build_cmd android_sync
                ;;
            update-api)
                build_cmd android_update_api
                ;;
            clean)
                android_clean
                ;;
            *)
                echo -e "$0 \033[47;31mUnknown CMD: $1\033[0m"
                exit 1
                ;;
        esac
        shift 1
    done
}

function android_functions_show()
{
    return 0
}

if [ "$1" = "get_parameters" ]; then
    android_functions_show
elif [ "$1" = "" ]; then
    android_usage
    exit $ERR
else
    android_command $@
    exit $ERR
fi
