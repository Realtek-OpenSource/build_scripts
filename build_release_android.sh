#!/bin/bash
SCRIPTDIR=$PWD
ANDROIDDIR=$SCRIPTDIR/android
KERNELDIR=$SCRIPTDIR/linux-kernel
MALIDIR=$SCRIPTDIR/mali
PHOENIXDIR=$SCRIPTDIR/phoenix
UBOOTDIR=$SCRIPTDIR/bootcode
TOOLCHAINDIR=$PHOENIXDIR/toolchain
PRODUCT_DEVICE_PATH=android/out/target/product/hercules32
source $SCRIPTDIR/build_prepare.sh
ERR=0
VERBOSE=
NCPU=`grep processor /proc/cpuinfo | wc -l`
MULTI=`expr $NCPU + 2`

# set umask here to prevent incorrect file permission
umask 0022

USING_SDK_TOOLCHAIN="NO"

if [ "$USING_SDK_TOOLCHAIN" = "YES" ]; then
TOOLCHAIN=$PWD/toolchain
#source java8.sh
export JAVA_HOME=$TOOLCHAIN/OpenJDK-1.8.0.112-x86_64-bin
export JRE_HOME=${JAVA_HOME}/jre
export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib
export PATH=${JAVA_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games
export PATH=~/bin:$PATH
echo $PATH
echo  "Java 8"
fi

#------------------------------
config_get CUSTOMER
config_get GIT_SERVER_URL
config_get SDK_BRANCH
config_get USER
config_get USE_RTK_REPO
config_get BUILDTYPE_ANDROID
export BUILDTYPE_ANDROID=$BUILDTYPE_ANDROID
echo -e "export \033[0;33mBUILDTYPE_ANDROID=$BUILDTYPE_ANDROID\033[0m"


init_android()
{
        [ ! -d "$ANDROIDDIR" ] && mkdir $ANDROIDDIR
        pushd $ANDROIDDIR > /dev/null
                if [ "$USE_RTK_REPO" == true ]; then
                        repo init -u ssh://$USER@$GIT_SERVER_URL:29418/$CUSTOMER/manifests -b $SDK_BRANCH -m android.xml --repo-url=ssh://$USER@$GIT_SERVER_URL:29418/git-repo
                else
                        repo init -u ssh://$USER@$GIT_SERVER_URL:29418/$CUSTOMER/manifests -b $SDK_BRANCH -m android.xml
                fi
        popd > /dev/null
        return 0
}

sync_android()
{
    ret=1
    [ ! -d "$ANDROIDDIR" ] && return 0
    pushd $ANDROIDDIR > /dev/null
        repo sync --force-sync
        ret=$?
        [ "$ret" = "0" ] && > .repo_ready
    popd > /dev/null
    return $ret
}

checkout_android()
{
    [ -e "$ANDROIDDIR/.repo_ready" ] && return 0
    init_android
    sync_android
    return $?
}

#------------------------------


build_android()
{
    pushd $ANDROIDDIR
        source ./env.sh
        lunch hercules32-userdebug
        make -j $MULTI $VERBOSE
        ERR=$?
    popd
    return $ERR
}

function build_cmd()
{
    $@
    ERR=$?
    printf "$* "
    if [ "$ERR" != "0" ]; then
        echo -e "\033[47;31m [ERROR] $ERR \033[0m"
        exit 1
    else
        echo "[OK]"
    fi
}


clean_firmware()
{
    pushd $ANDROIDDIR
        rm -rf out
        ERR=$?
    popd
}


ln_libOMX_realtek()
{

#echo"start copy ext_img"
#cd $PRODUCT_DEVICE_PATH/


echo "PRODUCT_DEVICE_PATH" $PRODUCT_DEVICE_PATH
cp android/ext_vendor/* $PRODUCT_DEVICE_PATH/vendor/lib/.
#cp android/ext_system/* $PRODUCT_DEVICE_PATH/system/lib/.
cd $PRODUCT_DEVICE_PATH/vendor/lib/
        echo "Starting force link OMX libraries"

ln -sf libOMX.realtek.audio.dec.so libOMX.realtek.audio.dec.secure.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.3gpp.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.avc.secure.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.avc.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.avs.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.divx3.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.flv.so
ln -sf libOMX.realtek.video.so libOMX.realtek.video.dec.hevc.secure.so
ln -sf libOMX.realtek.video.so libOMX.realtek.video.dec.hevc.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.mjpg.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.mpeg2.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.mpeg4.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.raw.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.rv30.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.rv40.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.rv.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.vc1.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.vp8.so
ln -sf libOMX.realtek.video.so libOMX.realtek.video.dec.vp9.secure.so
ln -sf libOMX.realtek.video.so libOMX.realtek.video.dec.vp9.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.wmv3.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.wmv.so
ln -sf libOMX.realtek.video.dec.so libOMX.realtek.video.dec.wvc1.so
ln -sf libOMX.realtek.video.enc.so libOMX.realtek.video.enc.avc.so
ln -sf libOMX.realtek.video.enc.so libOMX.realtek.video.enc.mpeg4.so

}




if [ "$1" = "" ]; then
    echo "$0 commands are:"
    echo "    build       "
    echo "    clean       "
else
    while [ "$1" != "" ]
    do
        case "$1" in
            clean)
                build_cmd clean_firmware
                ;;
            build)
                build_cmd build_android
                build_cmd ln_libOMX_realtek
                build_cmd build_android
                ;;
            checkout)
                build_cmd checkout_android
                ;;
            sync)
                build_cmd sync_android
                ;;

            *)
                echo -e "$0 \033[47;31mUnknown CMD: $1\033[0m"
                exit 1
                ;;
        esac
        shift 1
    done
fi

































exit $ERR
