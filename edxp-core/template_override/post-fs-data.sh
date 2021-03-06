#!/system/bin/sh

grep_prop() {
    local REGEX="s/^$1=//p"
    shift
    local FILES="$@"
    [[ -z "$FILES" ]] && FILES='/system/build.prop'
    sed -n "$REGEX" ${FILES} 2>/dev/null | head -n 1
}

MODDIR=${0%/*}

RIRU_PATH="/data/adb/riru"
RIRU_PROP="$(magisk --path)/.magisk/modules/riru-core/module.prop"
TARGET="${RIRU_PATH}/modules"

EDXP_VERSION=$(grep_prop version "${MODDIR}/module.prop")
EDXP_APICODE=$(grep_prop api "${MODDIR}/module.prop")

ANDROID_SDK=$(getprop ro.build.version.sdk)
BUILD_DESC=$(getprop ro.build.description)
PRODUCT=$(getprop ro.build.product)
MODEL=$(getprop ro.product.model)
MANUFACTURER=$(getprop ro.product.manufacturer)
BRAND=$(getprop ro.product.brand)
FINGERPRINT=$(getprop ro.build.fingerprint)
ARCH=$(getprop ro.product.cpu.abi)
DEVICE=$(getprop ro.product.device)
ANDROID=$(getprop ro.build.version.release)
BUILD=$(getprop ro.build.id)

RIRU_VERSION=$(grep_prop version $RIRU_PROP)
RIRU_VERCODE=$(grep_prop versionCode $RIRU_PROP)
RIRU_APICODE=$(cat "${RIRU_PATH}/api_version")

MAGISK_VERSION=$(magisk -v)
MAGISK_VERCODE=$(magisk -V)

#EDXP_MANAGER="org.meowcat.edxposed.manager"
#XP_INSTALLER="de.robv.android.xposed.installer"
#PATH_PREFIX="/data/user_de/0/"
#PATH_PREFIX_LEGACY="/data/user/0/"

livePatch() {
    # Should be deprecated now. This is for debug only.
    supolicy --live "allow system_server system_server process execmem" \
                    "allow system_server system_server memprotect mmap_zero"
}

#if [[ ${ANDROID_SDK} -ge 24 ]]; then
#    PATH_PREFIX="${PATH_PREFIX_PROT}"
#else
#    PATH_PREFIX="${PATH_PREFIX_LEGACY}"
#fi

#DEFAULT_BASE_PATH="${PATH_PREFIX}${EDXP_MANAGER}"
MISC_PATH=$(cat /data/adb/edxp/misc_path)
BASE_PATH="/data/misc/$MISC_PATH"

LOG_PATH="${BASE_PATH}/0/log"
CONF_PATH="${BASE_PATH}/0/conf"
DISABLE_VERBOSE_LOG_FILE="${CONF_PATH}/disable_verbose_log"
LOG_VERBOSE=true
OLD_PATH=${PATH}
PATH=${PATH#*:}
PATH_INFO=$(ls -ldZ "${BASE_PATH}")
PATH=${OLD_PATH}
PATH_OWNER=$(echo "${PATH_INFO}" | awk -F " " '{print $3":"$4}')
PATH_CONTEXT=$(echo "${PATH_INFO}" | awk -F " " '{print $5}')

if [[ -f ${DISABLE_VERBOSE_LOG_FILE} ]]; then
    LOG_VERBOSE=false
fi

# If logcat client is kicked out by klogd server, we'll restart it.
# However, if it is killed manually or by EdXposed Manager, we'll exit.
# Refer to https://github.com/ElderDrivers/EdXposed/pull/575 for more information.
loop_logcat() {
    while true
    do
        logcat $*
        if [[ $? -ne 1 ]]; then
            break
        fi
    done
}

start_log_cather () {
    LOG_FILE_NAME=$1
    LOG_TAG_FILTERS=$2
    CLEAN_OLD=$3
    START_NEW=$4
    LOG_FILE="${LOG_PATH}/${LOG_FILE_NAME}.log"
    PID_FILE="${LOG_PATH}/${LOG_FILE_NAME}.pid"
    mkdir -p ${LOG_PATH}
    if [[ ${CLEAN_OLD} == true ]]; then
        rm "${LOG_FILE}.old"
        mv "${LOG_FILE}" "${LOG_FILE}.old"
    fi
    rm "${LOG_PATH}/${LOG_FILE_NAME}.pid"
    if [[ ${START_NEW} == false ]]; then
        return
    fi
    touch "${LOG_FILE}"
    touch "${PID_FILE}"
    echo "--------- beginning of head">>"${LOG_FILE}"
    echo "EdXposed Log">>"${LOG_FILE}"
    echo "Powered by Log Catcher">>"${LOG_FILE}"
    echo "QQ support group: 855219808">>"${LOG_FILE}"
    echo "Telegram support group: @Code_Of_MeowCat">>"${LOG_FILE}"
    echo "Telegram channel: @EdXposed">>"${LOG_FILE}"
    echo "--------- beginning of information">>"${LOG_FILE}"
    echo "Manufacturer: ${MANUFACTURER}">>"${LOG_FILE}"
    echo "Brand: ${BRAND}">>"${LOG_FILE}"
    echo "Device: ${DEVICE}">>"${LOG_FILE}"
    echo "Product: ${PRODUCT}">>"${LOG_FILE}"
    echo "Model: ${MODEL}">>"${LOG_FILE}"
    echo "Fingerprint: ${FINGERPRINT}">>"${LOG_FILE}"
    echo "ROM description: ${BUILD_DESC}">>"${LOG_FILE}"
    echo "Architecture: ${ARCH}">>"${LOG_FILE}"
    echo "Android build: ${BUILD}">>"${LOG_FILE}"
    echo "Android version: ${ANDROID}">>"${LOG_FILE}"
    echo "Android sdk: ${ANDROID_SDK}">>"${LOG_FILE}"
    echo "EdXposed version: ${EDXP_VERSION}">>"${LOG_FILE}"
    echo "EdXposed api: ${EDXP_APICODE}">>"${LOG_FILE}"
    echo "Riru version: ${RIRU_VERSION} (${RIRU_VERCODE})">>"${LOG_FILE}"
    echo "Riru api: ${RIRU_APICODE}">>"${LOG_FILE}"
    echo "Magisk: ${MAGISK_VERSION%:*} (${MAGISK_VERCODE})">>"${LOG_FILE}"
    loop_logcat -f "${LOG_FILE}" *:S "${LOG_TAG_FILTERS}" &
    LOG_PID=$!
    echo "${LOG_PID}">"${LOG_PATH}/${LOG_FILE_NAME}.pid"
}

# install stub if manager not installed
if [[ "$(pm path org.meowcat.edxposed.manager 2>&1)" == "" && "$(pm path de.robv.android.xposed.installer 2>&1)" == "" ]]; then
    NO_MANAGER=true
fi
if [[ ${NO_MANAGER} == true ]]; then
    cp "${MODDIR}/EdXposed.apk" "/data/local/tmp/EdXposed.apk"
    LOCAL_PATH_INFO=$(ls -ldZ "/data/local/tmp")
    LOCAL_PATH_OWNER=$(echo "${LOCAL_PATH_INFO}" | awk -F " " '{print $3":"$4}')
    LOCAL_PATH_CONTEXT=$(echo "${LOCAL_PATH_INFO}" | awk -F " " '{print $5}')
    chcon "${LOCAL_PATH_CONTEXT}" "/data/local/tmp/EdXposed.apk"
    chown "${LOCAL_PATH_OWNER}" "/data/local/tmp/EdXposed.apk"
    pm install "/data/local/tmp/EdXposed.apk"
    rm -f "/data/local/tmp/EdXposed.apk"
fi

# execute live patch if rule not found
[[ -f "${MODDIR}/sepolicy.rule" ]] || livePatch

# start_verbose_log_catcher
start_log_cather all "EdXposed:V XSharedPreferences:V EdXposed-Bridge:V EdXposedManager:V XposedInstaller:V *:F" true ${LOG_VERBOSE}

# start_bridge_log_catcher
start_log_cather error "XSharedPreferences:V EdXposed-Bridge:V" true true

if [[ -f "/data/adb/riru/modules/edxp.prop" ]]; then
    CONFIG=$(cat "/data/adb/riru/modules/edxp.prop")
    [[ -d "${TARGET}/${CONFIG}" ]] || mkdir -p "${TARGET}/${CONFIG}"
    cp "${MODDIR}/module.prop" "${TARGET}/${CONFIG}/module.prop"
fi

chcon -R u:object_r:system_file:s0 "${MODDIR}"
chcon -R ${PATH_CONTEXT} "${LOG_PATH}"
chown -R ${PATH_OWNER} "${LOG_PATH}"
chmod -R 666 "${LOG_PATH}"

if [[ ! -z "${MISC_PATH}" ]]; then
    mkdir -p "${BASE_PATH}/cache"
    chcon -R u:object_r:magisk_file:s0 "${BASE_PATH}"
    chmod 771 "${BASE_PATH}"
    chmod 777 "${BASE_PATH}/cache"
fi
rm -f /data/adb/edxp/new_install
