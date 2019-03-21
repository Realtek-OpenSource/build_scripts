#!/bin/bash

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh

if [ "$1" != "get_parameters" ]; then
    source $SCRIPTDIR/build_linux_kernel.sh get_parameters
fi

source $SCRIPTDIR/env_image.sh

ERR=0

function image_command()
{
    while [ "$1" != "" ]
    do
        case "$1" in
            config)
                image_config
                ;;
            init)
                image_init
                ;;
            checkout)
                image_config
                build_cmd image_checkout
                ;;
            sync)
                image_config
                build_cmd image_sync
                ;;
            build)
                image_config
                build_cmd image_build
                ;;
            clean)
                build_cmd image_clean
                ;;
            *)
                echo -e "$0 \033[47;31mUnknown CMD: $1\033[0m"
                exit 1
                ;;
        esac
        shift 1
    done
}

function image_usage()
{
    echo "$0 commands are:"
    echo "    config      "
    echo "    checkout    "
    echo "    sync        "
    echo "    build       "
    echo "    rescue      "
}

function image_functions_show()
{
    return 0
    # echo image_config_prepare
    # echo image_config
    # echo image_checkout
    # echo image_prepare
    # echo image_update_partition_size
    # echo image_build
    # echo image_sync
    # echo image_command
    # echo image_usage
    # echo image_functions_show
}

if [ "$1" = "get_parameters" ]; then
    image_functions_show
elif [ "$1" = "" ]; then
    image_usage
    exit $ERR
else
    image_command $@
    exit $ERR
fi
