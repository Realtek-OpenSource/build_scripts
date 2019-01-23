#!/bin/bash

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh

source $SCRIPTDIR/env_kernel.sh

ERR=0

function kernel_usage()
{
    echo "$0 commands are:"
    echo "    config      "
    echo "    checkout    "
    echo "    clean       "
    echo "    sync        "
    echo "    build    (Image+modules+dtbs+paragon+wifi+bluetooth--Normal+Golden)"
    echo "    external (paragon+wifi+bluetooth+...)"
    echo "    kernel   (Image+modules+dtbs)"
	echo "    golden   (Golden-Image+modules+dtbs)"
    echo "    modules     "
    echo "    uImage      "
    echo "    Image       "
    echo "    dtbs        "
    echo "    dtboimg     "
}

function kernel_command()
{
    while [ "$1" != "" ]
    do
        case "$1" in
            init)
                build_cmd kernel_init
                ;;
            config)
                build_cmd kernel_version
                build_cmd kernel_config
                ;;
            checkout)
                build_cmd kernel_checkout
                ;;
            clean)
                build_cmd kernel_clean
                ;;
            sync)
                build_cmd kernel_checkout
                build_cmd kernel_sync
                ;;
            build)
                build_cmd kernel_prepare
                build_cmd kernel_golden_build $KERNEL_IMAGE modules dtbs
                build_cmd kernel_prepare
                build_cmd kernel_build $KERNEL_IMAGE modules dtbs
                build_cmd kernel_dtboimg
                build_cmd kernel_external_modules
                ;;
            kernel)
                build_cmd kernel_prepare
                build_cmd kernel_build $KERNEL_IMAGE modules dtbs
                build_cmd kernel_dtboimg
                ;;
            golden)
                build_cmd kernel_prepare
                build_cmd kernel_golden_build $KERNEL_IMAGE modules dtbs
                ;;
            Image)
                build_cmd kernel_prepare
                build_cmd kernel_build $KERNEL_IMAGE
                ;;
            uImage)
                build_cmd kernel_prepare
                build_cmd kernel_build $KERNEL_IMAGE
                ;;
            modules)
                build_cmd kernel_prepare
                build_cmd kernel_build modules
                ;;
            dtbs)
                build_cmd kernel_prepare
                build_cmd kernel_build dtbs
                ;;
            dtboimg)
                build_cmd kernel_prepare
                build_cmd kernel_dtboimg
		;;
            external)
                build_cmd kernel_prepare
                build_cmd kernel_external_modules
                ;;
            *)
                echo -e "$0 \033[47;31mUnknown CMD: $1\033[0m"
                exit 1
                ;;
        esac
        shift 1
    done
}

function kernel_functions_show()
{
    return 0
    # echo "kernel_init"
    # echo "kernel_checkout"
    # echo "kernel_config"
    # echo "kernel_config_check"
    # echo "kernel_build"
    # echo "kernel_external_modules"
    # echo "kernel_clean"
    # echo "kernel_sync"
    # echo "kernel_check_toolchain"
    # echo "kernel_prepare_parameters"
    # echo "kernel_prepare"
}

if [ "$1" = "get_parameters" ]; then
    kernel_functions_show
elif [ "$1" = "" ]; then
    kernel_usage
    exit $ERR
else
    kernel_command $@
    exit $ERR
fi
