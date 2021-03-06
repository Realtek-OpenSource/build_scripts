#!/bin/bash
TOPDIR=$PWD
SCRIPTDIR=$TOPDIR
ANDROIDDIR=$TOPDIR/android
KERNELDIR=$TOPDIR/linux-kernel
MALIDIR=$TOPDIR/mali
PLATFORMDIR=$TOPDIR/phoenix
BOOTCODEDIR=$TOPDIR/bootcode
IMAGEDIR=$TOPDIR/image_file_creator
QASUPPLIEMENT=$TOPDIR/qa_supplement
RTKSRC=$TOPDIR/software_Phoenix_RTK
OPENWRTDIR=$SCRIPTDIR/OpenWrt-ImageBuilder-rtd1295-mnas_emmc.Linux-x86_64
TOOLCHAINDIR=$PLATFORMDIR/toolchain
CONFIG_MAGIC=CONFIG_
CONFIG_FILE=$TOPDIR/.build_config
VERBOSE=
NCPU=`grep processor /proc/cpuinfo | wc -l`
MULTI=`expr $NCPU + 2`

source $TOPDIR/cmd_config.sh

export USER=$(whoami)
export JAVA_HOME=$TOPDIR/toolchain/OpenJDK-1.8.0.112-x86_64-bin/
export JRE_HOME=${JAVA_HOME}/jre
export CLASSPATH=.:${JAVA_HOME}/lib:${JRE_HOME}/lib
export PATH=${JAVA_HOME}/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games
export PATH=~/bin:$PATH
echo $PATH
echo  "Java 8"

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

#   case 1. config_set TEST
#   case 2. config_set TEST {force data}
function config_set()
{
    item=$1
    config_item=${CONFIG_MAGIC}${item}
    config_data=${!item}

    if [ "$2" != "" ]; then
        shift 1
        config_data=$@
    fi

    config_data=`echo $config_data|awk '{
    {printf "%s",$1}
    if (NF>1) {
        for (i=2; i <= NF; i++) { printf " %s",$i}
        }
    {printf "\n"}}'`

    [ -e $CONFIG_FILE ] &&
        FIND=`cat $CONFIG_FILE | grep $config_item | wc -l` || FIND=0

    [ "$FIND" != "0" ] && sed -i "/${config_item}/d" $CONFIG_FILE

    echo ${config_item} ${config_data} >> $CONFIG_FILE

    if [ "${config_data}" != "" ]; then
        export ${item}="${config_data}"
        echo -e "export \033[0;33m${item}=${config_data}\033[0m"
    fi
}

#   case 1. config_get TEST
#   case 2. config_get TEST {default value}
#   case 3. config_get TEST $TEST
function config_get()
{
    item=$1
    config_item=${CONFIG_MAGIC}${item}
    #config_data=${!item}
    config_data=
    [ -e $CONFIG_FILE ] &&
        FIND=`cat $CONFIG_FILE | grep $config_item | wc -l` || FIND=0

    if [ "$FIND" = "1" ]; then
        #config_data=`cat $CONFIG_FILE | grep $config_item | awk '{print $2}'`
        config_data=`cat $CONFIG_FILE | grep $config_item |\
            awk '{
        for (i=2; i <= NF; i++) {
            if (i==2) {printf $i}
            else {printf " "$i}
            }}'`
        ret=0
    elif [ "$FIND" = "0" ]; then
        # NOT FIND
        if [ "$config_data" = "" ] && [ "$2" != "" ]; then
            config_data=$2
        fi
        ret=1
    else
        ret=2
        cat $CONFIG_FILE | grep $config_item
        echo -e "\033[47;31m [ERROR] $ret \033[0m"
        exit $ret
    fi

    #config_set ${item} ${config_data}
    [ "$config_data" != "" ] && export ${item}="${config_data}"
    return $ret
}

function config_menu()
{
    echo "-------------------------------------------------"
    i=0
    item=$1
    list=${!2}
    def_item=$3
    ERR=1
    for b in $list
    do
        if [ "$b" = "$def_item" ]; then
            echo -e "    $i\t: \033[1;36m$b\033[0m"
        else
            echo -e "    $i\t: $b"
        fi
        i=`expr $i + 1`
    done

    if [ "$def_item" != "" ]; then
        read -p "select the $item (default $def_item) : " id
    else
        read -p "select the $item : " id
    fi

    if [ "$id" = "" ] && [ "$def_item" != "" ]; then
        id=$def_item
    fi
    echo $id

    i=0
    for b in $list
    do
        if [ "$id" = "$i" ] || [ "$id" = "$b" ]; then
            config_set $item $b
            ERR=0
            break
        fi
        i=`expr $i + 1`
    done

    if [ "$ERR" != "0" ]; then
        echo -e "\033[47;31m [ERROR] $ERR \033[0m"
        echo "config_menu [item] $item [list] $list [default] $def_item"
        exit 1
    fi
    return 0
}

function config_get_list_menu()
{
    config_get $1 && return 0
    item=$1
    from_list=${!2}
    bak=0
    while [ "$bak" = "0" ]
    do
        item_list=${!item}
        i=0
        for fl in $from_list
        do
            match=0
            printf "    $i  "
            for il in $item_list
            do
                if [ "$fl" = "$il" ]; then
                    match=1
                    break
                fi
            done
            [ "$match" = "0" ] && printf "[ ]" || printf "[*]"
            printf " $fl\n"
            i=`expr $i + 1`
        done

        read -p "select the $item : " id

        if [ "$id" = "" ]; then
            bak=1
            break
        fi

        i=0
        for fl in $from_list
        do
            if [ "$id" = "$fl" ] || [ "$id" = "$i" ]; then
                match=0
                for il in $item_list
                do
                    if [ "$fl" = "$il" ]; then
                        match=1
                        break
                    fi
                done

                [ "$match" = "1" ] && list_del $item $fl || list_add $item $fl

                break
            fi
            i=`expr $i + 1`
        done
    done
    config_set $item
}

function config_get_menu()
{
    config_get $1 || config_menu $@
}

function config_get_bool()
{
    def_select=$2
    config_get $1
    if [ "$?" != "0" ]; then
        case "$def_select" in
            [Yy] | [Yy]es | YES | 1 | [Tt]rue | TRUE )
                printf "$1 [\033[1;36mY\033[0m/n] : " && read select
                [ "$select" = "" ] && select="YES"
                ;;
            *)
                printf "$1 [y/\033[1;36mN\033[0m] : " && read select
                [ "$select" = "" ] && select="NO"
                ;;
        esac

        #printf "\n"

        case "$select" in
            [Yy] | [Yy]es | YES | 1 | [Tt]rue | TRUE )
                data="true"
                ;;
            *)
                data="false"
                ;;
        esac
        config_set $1 $data
    fi

    if [ "${!1}" = "true" ]; then
        ret=0
    else
        ret=1
    fi

    return $ret
}

function config_get_true()
{
    config_get $1 || return 1
    [ "`echo ${!1} | awk '{print $1}'`" = "true" ] && return 0 || return 1
}

function config_get_false()
{
    config_get $1 || return 0
    [ "`echo ${!1} | awk '{print $1}'`" = "true" ] && return 1 || return 0
}

function config_show()
{
    echo "-----------------------------------------------------------------------------"
    echo "  Config File : $CONFIG_FILE                                                 "
    echo
    cat $CONFIG_FILE |\
        cut -c `echo $CONFIG_MAGIC | wc -c`-|\
        awk '{
    for (i=1; i <= NF; i++) {
        if (i==1)               {printf "\t\033[1;32m%-25s \t",$i}
        else if ($i=="true")    {printf "\033[1;34m %s ",$i}
        else if ($i=="false")   {printf "\033[1;31m %s ",$i}
        else                    {printf "\033[1;33m %s ",$i}
        }
        printf "\033[0m \n"}'
    echo
    echo "-----------------------------------------------------------------------------"
    return 0
}


function check_target_branch()
{
    config_get BRANCH_QA_TARGET
    config_get BRANCH_PARENT
    config_get MANIFEST_BRANCH
    if [ "$?" == "0" ]; then
        return
    fi

    if [ ! -d .manifest ]; then
        build_cmd git clone $GERRIT_MANIFEST .manifest
    fi
    pushd .manifest > /dev/null
        BRANCH_LIST=
        BRANCH_LIST="$BRANCH_LIST `git branch -r | sed -n 's/\(origin\/phoenix-kk-4.4.4_r1-b\/.*\)/\1/p'`"
        BRANCH_LIST="$BRANCH_LIST `git branch -r | sed -n 's/\(origin\/phoenix-ll-5.0.0-b\/.*\)/\1/p'`"
        BRANCH_LIST="$BRANCH_LIST `git branch -r | sed -n 's/\(origin\/phoenix-mm-6.0.0-b\/.*\)/\1/p'`"
        BRANCH_LIST="$BRANCH_LIST `git branch -r | sed -n 's/\(origin\/android-7.0.0-b\/.*\)/\1/p'`"
        BRANCH_LIST="$BRANCH_LIST `git branch -r | sed -n 's/\(origin\/android-8.0.0-b\/.*\)/\1/p'`"
        BRANCH_LIST="$BRANCH_LIST `git branch -r | sed -n 's/\(origin\/android-9.0.0-b\/.*\)/\1/p'`"
    popd > /dev/null
    config_menu MANIFEST_BRANCH BRANCH_LIST origin/phoenix-ll-5.0.0-b/trunk-5.0.0_r2
    IFS='/' read REMOTE BRANCH_PARENT BRANCH_QA_TARGET <<< "$MANIFEST_BRANCH"
    config_set BRANCH_QA_TARGET
    config_set BRANCH_PARENT
}

function get_android_major_version()
{
    config_get BRANCH_PARENT
    if [ "$BRANCH_PARENT" = "phoenix-kk-4.4.4_r1-b" ]; then
        echo 4;
    elif [ "$BRANCH_PARENT" = "phoenix-ll-5.0.0-b" ]; then
        echo 5;
    elif [ "$BRANCH_PARENT" = "phoenix-mm-6.0.0-b" ]; then
        echo 6;
    elif [ "$BRANCH_PARENT" = "android-7.0.0-b" ]; then
        echo 7;
    elif [ "$BRANCH_PARENT" = "android-8.0.0-b" ]; then
        echo 8;
    elif [ "$BRANCH_PARENT" = "android-9.0.0-b" ]; then
        echo 9;
    else
        echo "unknown BRANCH_PARENT=$BRANCH_PARENT";
        exit 1;
    fi
}

function android_product_out_dir_get()
{
    android_env > /dev/null 2>&1
    item=$1
    dir=$ANDROID_PRODUCT_OUT
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function check_repo_para()
{
    REPO_PARA=

    if check_mirror ; then
        list_add REPO_PARA $REFERENCE
    fi

    REPO_URL_LIST=
    list_add REPO_URL_LIST NULL
    list_add REPO_URL_LIST ${GERRIT_SERVER}/aosp/git-repo
    list_add REPO_URL_LIST https://gerrit.googlesource.com/git-repo
    list_add REPO_URL_LIST Other
    REPO_URL_DEFAULT=NULL
    config_get_menu REPO_URL REPO_URL_LIST $REPO_URL_DEFAULT

    if [ "$REPO_URL" = "Other" ]; then
        read -p "REPO_URL : " REPO_URL
        config_set REPO_URL
    elif [ "$REPO_URL" = "NULL" ]; then
        REPO_URL=
    fi
    if [ "$REPO_URL" != "" ]; then
        list_add REPO_PARA --repo-url=${REPO_URL}
    fi

    ### repo verify ###
    config_get_bool REPO_VERIFY true
    config_get_false REPO_VERIFY && list_add REPO_PARA --no-repo-verify

    [ "$REPO_PARA" != "" ] && echo repo extra parameters : $REPO_PARA
}


check_target_branch
#check_repo_para
