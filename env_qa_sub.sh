#!/bin/bash
[ "$ENV_QA_SUB_SOURCE" != "" ] && return
ENV_QA_SUB_SOURCE=1

[ "$SCRIPTDIR" = "" ] && SCRIPTDIR=$PWD
source $SCRIPTDIR/build_prepare.sh

QA_SUPDIR=$TOPDIR/qa_supplement


function qa_sub_dir_get()
{
    item=$1
    dir=$QA_SUPDIR
    [ "$item" != "" ] && export ${item}="${dir}" || echo ${dir}
    return 0
}

function qa_sub_init()
{
    [ ! -d "$QA_SUPDIR" ] && mkdir $QA_SUPDIR
    pushd $QA_SUPDIR > /dev/null
    repo init -u $GERRIT_MANIFEST -b $BRANCH_PARENT/$BRANCH_QA_TARGET -m qa_supplement.xml $REPO_PARA
    ERR=$?
    popd > /dev/null
    return $ERR;
}

function qa_sub_sync()
{
    ERR=0
    if [ -d "$QA_SUPDIR" ]; then
        pushd $QA_SUPDIR > /dev/null
        repo sync --force-sync
        ERR=$?
        popd > /dev/null
    else
        ERR=1
    fi
    return $ERR
}

function qa_sub_checkout()
{
    ERR=0
    if [ ! -e "${QA_SUPDIR}/.repo_ready" ]; then
        qa_sub_init && qa_sub_sync && (> ${QA_SUPDIR}/.repo_ready) || ERR=1
    fi
    return $ERR
}
