#!/bin/bash
SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh
ERR=0
config_get CUSTOMER
config_get GIT_SERVER_URL
config_get SDK_BRANCH
config_get USER
config_get USE_RTK_REPO
config_get TARGET_BUILD_TYPE
config_get BUILDTYPE_ANDROID
config_get REALTEK_1395_CHIP
MODULE_PATH=$ANDROIDDIR/out/target/product/$BUILDTYPE_ANDROID/system/vendor/modules


# set umask here to prevent incorrect file permission
umask 0022

config_show

git clone ssh://$USER@$GIT_SERVER_URL:29418/SDK_release/toolchain


check_build_target()
{
	pushd $SCRIPTDIR > /dev/null
#	[ ! -d "$BOOTCODEDIR" ] && git clone ssh://$USER@$GIT_SERVER_URL:29418/$CUSTOMER/bootcode -b $SDK_BRANCH
	[ ! -d "$IMAGEDIR" ] && git clone ssh://$USER@$GIT_SERVER_URL:29418/$CUSTOMER/image_file_creator -b $SDK_BRANCH
#	[ ! -d "$QASUPPLEMENT" ] && git clone ssh://$USER@$GIT_SERVER_URL:29418/$CUSTOMER/qa_supplement -b $SDK_BRANCH
	popd > /dev/null
	return $ERR;
}

target_build()
{
#	pushd $BOOTCODEDIR > /dev/null
#		build_cmd ./build_rtk_lk.sh rtd1395
#	popd > /dev/null

	pushd $SCRIPTDIR > /dev/null
		if [ "$TARGET_BUILD_TYPE" == openwrt ]; then
			build_cmd ./build_release_android.sh build
			build_cmd ./build_release_openwrt.sh build
			cp -f $OPENWRTDIR/bin/rtd1295-glibc/install.img $SCRIPTDIR/install.img-OpenWRT-`date +%Y-%m-%d`
		elif [ "$TARGET_BUILD_TYPE" == pure_android ]; then
			[ ! -d "$IMAGEDIR" ] && git clone ssh://$USER@$GIT_SERVER_URL:29418/$CUSTOMER/image_file_creator -b $SDK_BRANCH
                        build_cmd ./build_release_linux_kernel.sh build
			build_cmd ./build_release_android.sh build
			build_cmd ./build_image.sh build
			cp -f $IMAGEDIR/install.img $SCRIPTDIR/install.img-OTT-`date +%Y-%m-%d`
		fi

	popd > /dev/null
	return $ERR;
}

target_checkout()
{
	pushd $SCRIPTDIR > /dev/null
		if [ "$TARGET_BUILD_TYPE" == openwrt ]; then
			build_cmd ./build_release_android.sh checkout
			build_cmd ./build_release_openwrt.sh checkout
			DATE=`cat $SCRIPTDIR/.build_config |grep SYNC_DATE: | awk '{print $2}'`
			NEW_DATE=`date +%Y-%m-%d`	
			sed -i 's/'$DATE'/'$NEW_DATE'/g' $SCRIPTDIR/.build_config
		elif [ "$TARGET_BUILD_TYPE" == pure_android ]; then
			build_cmd ./build_release_android.sh checkout
			build_cmd ./build_release_linux_kernel.sh checkout
		fi

	popd > /dev/null
	return $ERR;
}

target_sync()
{
    pushd $SCRIPTDIR > /dev/null
	git pull
        if [ "$TARGET_BUILD_TYPE" == openwrt ]; then
            if [ ! -d "$BOOTCODEDIR" ]; then
                git clone ssh://$USER@$GIT_SERVER_URL:29418/$CUSTOMER/bootcode_a01 bootcode
            else
                pushd $BOOTCODEDIR > /dev/null
                DATE=`cat $SCRIPTDIR/.build_config |grep SYNC_DATE: | awk '{print $2}'`
                git pull;git log --stat --since="$DATE" >> /tmp/change_log.txt;mv /tmp/change_log.txt $SCRIPTDIR/chang    e_log_bootcode_`date +%Y-%m-%d`.txt
                popd > /dev/null
            fi

            build_cmd ./build_release_android.sh sync
            build_cmd ./build_release_openwrt.sh sync
            DATE=`cat $SCRIPTDIR/.build_config |grep SYNC_DATE: | awk '{print $2}'`
            NEW_DATE=`date +%Y-%m-%d`
            sed -i 's/'$DATE'/'$NEW_DATE'/g' $SCRIPTDIR/.build_config
        elif [ "$TARGET_BUILD_TYPE" == pure_android ]; then
            if [ ! -d "$BOOTCODEDIR" ]; then
                git clone ssh://$USER@$GIT_SERVER_URL:29418/$CUSTOMER/bootcode -b $SDK_BRANCH
            else           
                pushd $BOOTCODEDIR > /dev/null
                DATE=`cat $SCRIPTDIR/.build_config |grep SYNC_DATE: | awk '{print $2}'`
                git pull;git log --stat --since="$DATE" >> /tmp/change_log.txt;mv /tmp/change_log.txt $SCRIPTDIR/change_log_bootcode_`date +%Y-%m-%d`.txt
                popd > /dev/null 
			fi
 	    build_cmd ./build_release_android.sh sync
            build_cmd ./build_release_linux_kernel.sh sync
 			DATE=`cat $SCRIPTDIR/.build_config |grep SYNC_DATE: | awk '{print $2}'`
            NEW_DATE=`date +%Y-%m-%d`
            sed -i 's/'$DATE'/'$NEW_DATE'/g' $SCRIPTDIR/.build_config
       fi

	pushd $IMAGEDIR > /dev/null
		git pull
	popd > /dev/null

    popd > /dev/null
    return $ERR;
}

clean_module()
{
	[ -d "$MODULE_PATH" ] && rm $MODULE_PATH/*
}


if [ "$1" = "" ]; then
    echo "$0 commands are:"
    echo "    checkout    "
    echo "    sync        "
    echo "    build       "
else
    while [ "$1" != "" ]
    do
        case "$1" in
		build)
			clean_module
			check_build_target
			target_build
                ;;
		checkout)
			check_build_target
			target_checkout
		;;
		sync)
			check_build_target
			target_sync
		;;
		clean)
			clean_module
			./build_image.sh clean
			./build_release_android.sh clean
			./build_release_linux_kernel.sh clean
		;;
		*)
                echo -e "$0 \033[47;31mUnknown CMD: $1\033[0m"
                exit 1
                ;;
        esac
        shift 1
    done
fi


