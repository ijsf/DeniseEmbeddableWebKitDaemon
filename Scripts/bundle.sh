#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR=$1
DYLIBBUNDLER=${PROJECT_DIR}/tools/macdylibbundler/dylibbundler
WEBKITGTK_PATH=${PROJECT_DIR}/vendor/webkitgtk_denise
WEBKITGTK_BUILD_PATH=${WEBKITGTK_PATH}/build
APP_BUNDLE_PATH=$2
APP_BUNDLE_EXECUTABLE=$3
TMP_PATH=/tmp/denise

rm -rf ${TMP_PATH}
mkdir -p ${TMP_PATH} &>/dev/null

cp ${WEBKITGTK_BUILD_PATH}/lib/*.dylib ${TMP_PATH}
cp /usr/local/lib/libicu* ${TMP_PATH}

pushd ${TMP_PATH} &>/dev/null
    ${DYLIBBUNDLER} --install-path '@loader_path/../libs/' -od -b -x ${APP_BUNDLE_PATH}/Contents/MacOS/${APP_BUNDLE_EXECUTABLE} -d ${APP_BUNDLE_PATH}/Contents/libs/ <<< ${TMP_PATH}
popd
