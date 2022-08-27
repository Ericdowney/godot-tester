#!/bin/bash -e
# switching to bash for pipestatus functionality

set -e

GODOT_VERSION=$1
RELEASE_TYPE=$2
PROJECT_DIRECTORY=$3
IS_MONO=$4
IMPORT_TIME=$5
TEST_TIME=$6
DIRECT_SCENE=$7
IGNORE_ERROR=$8
CONFIG_FILE=$9

GODOT_SERVER_TYPE="headless"
CUSTOM_DL_PATH="~/custom_dl_folder"
RUN_OPTIONS="-s addons/gut/gut_cmdln.gd -ginclude_subdirs -gexit"

if [ "$RELEASE_TYPE" = "stable" ]; then
    DL_PATH_SUFFIX=""
else
    DL_PATH_SUFFIX="/${RELEASE_TYPE}"
fi

# if download places changes, will need updates to this if/else
if [ "$IS_MONO" = "true" ]; then
    GODOT_RELEASE_TYPE="${RELEASE_TYPE}_mono"
    DL_PATH_EXTENSION="${GODOT_VERSION}${DL_PATH_SUFFIX}/mono/"
    GODOT_EXTENSION="_64"
    # this is a folder for mono versions
    FULL_GODOT_NAME=Godot_v${GODOT_VERSION}-${GODOT_RELEASE_TYPE}_linux_${GODOT_SERVER_TYPE}
else
    GODOT_RELEASE_TYPE="${RELEASE_TYPE}"
    DL_PATH_EXTENSION="${GODOT_VERSION}${DL_PATH_SUFFIX}/"
    GODOT_EXTENSION=".64"
    FULL_GODOT_NAME=Godot_v${GODOT_VERSION}-${GODOT_RELEASE_TYPE}_linux_${GODOT_SERVER_TYPE}
fi

# these are mutually exclusive - direct scenes cannot take a config file but they can
# have all those options set on the scene itself anyways
if [ "$DIRECT_SCENE" != "false" ]; then
    RUN_OPTIONS="${DIRECT_SCENE}"
elif [ "$CONFIG_FILE" != "res://.gutconfig.json" ]; then
    RUN_OPTIONS="${RUN_OPTIONS} -gconfig=${CONFIG_FILE}"
fi

cd ./${PROJECT_DIRECTORY}

mkdir -p ${CUSTOM_DL_PATH}
mkdir -p ./addons/gut/.cli_add
mv -n /__rebuilder.gd ./addons/gut/.cli_add
mv -n /__rebuilder_scene.tscn ./addons/gut/.cli_add

# in case this was somehow there already, but broken
rm -rf ${CUSTOM_DL_PATH}/${FULL_GODOT_NAME}${GODOT_EXTENSION}
rm -f ${CUSTOM_DL_PATH}/${FULL_GODOT_NAME}${GODOT_EXTENSION}.zip
# setup godot environment
DL_URL="https://downloads.tuxfamily.org/godotengine/${DL_PATH_EXTENSION}${FULL_GODOT_NAME}${GODOT_EXTENSION}.zip"
echo "downloading godot from ${DL_URL} ..."
yes | wget -q ${DL_URL} -P ${CUSTOM_DL_PATH}
mkdir -p ~/.cache
mkdir -p ~/.config/godot
echo "unzipping ..."
yes | unzip -q ${CUSTOM_DL_PATH}/${FULL_GODOT_NAME}${GODOT_EXTENSION}.zip -d ${CUSTOM_DL_PATH}
chmod -R 777 ${CUSTOM_DL_PATH}

echo "running test suites ..."

set +e
# run tests
if [ "$IS_MONO" = "true" ]; then
    # need to init the imports
    # workaround for -e -q and -e with timeout failing
    # credit: https://github.com/Kersoph/open-sequential-logic-simulation/pull/4/files
    timeout ${IMPORT_TIME} ./${CUSTOM_DL_PATH}/${FULL_GODOT_NAME}${GODOT_EXTENSION}/${FULL_GODOT_NAME}.64 --editor addons/gut/.cli_add/__rebuilder_scene.tscn
    timeout ${TEST_TIME} ./${CUSTOM_DL_PATH}/${FULL_GODOT_NAME}${GODOT_EXTENSION}/${FULL_GODOT_NAME}.64 ${RUN_OPTIONS} 2>&1
else
    timeout ${IMPORT_TIME} ./${CUSTOM_DL_PATH}/${FULL_GODOT_NAME}${GODOT_EXTENSION} --editor addons/gut/.cli_add/__rebuilder_scene.tscn
    timeout ${TEST_TIME} ./${CUSTOM_DL_PATH}/${FULL_GODOT_NAME}${GODOT_EXTENSION} ${RUN_OPTIONS} 2>&1
fi

# Check GUT output and save exit value, 0 = success, 1 = fail
exitval=$?

# removing scene used to rebuild import files
rm -rf ./addons/gut/.cli_add/__rebuilder.gd
rm -rf ./addons/gut/.cli_add/__rebuilder_scene.tscn

rm -rf ${CUSTOM_DL_PATH}/${FULL_GODOT_NAME}${GODOT_EXTENSION}
rm -f ${CUSTOM_DL_PATH}/${FULL_GODOT_NAME}${GODOT_EXTENSION}.zip

exit ${exitval}
