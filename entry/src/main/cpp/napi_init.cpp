#define LOG_TAG "NativeEntry"

#include "Logging.hpp"
#include "NapiUtils.hpp"
#include "filemanagement/clouddiskmanager/oh_cloud_disk_manager.h"
#include "magic_enum.hpp"
#include "napi/native_api.h"

#include <string.h>
// #include <syscap_ndk.h>

static bool canIUse(const char *)
{
    return true;
}

static napi_value DoAdd(napi_env env, napi_callback_info info)
{
    const auto input = NapiArgs<napi_string, napi_string>::Get(env, info);
    if (!input.has_value())
        return nullptr;

    const auto [alias, filePath] = *input;
    LogInfo("input: %{public}s", filePath.c_str());

    if (canIUse("SystemCapability.FileManagement.CloudDiskManager"))
    {
        CloudDisk_SyncFolder folder;
        folder.displayNameInfo.customAlias = (char *) alias.data();
        folder.displayNameInfo.customAliasLength = alias.length();
        folder.displayNameInfo.displayNameResId = 0;
        folder.state = CloudDisk_SyncFolderState::ACTIVE;
        folder.path.value = strdup(filePath.c_str());
        folder.path.length = filePath.length();
        const auto ret = OH_CloudDisk_RegisterSyncFolder(&folder);

        LogInfo("returned: %{public}s", magic_enum::enum_name<CloudDisk_ErrorCode>(ret).data());

        napi_value retValue;
        napi_create_int32(env, ret, &retValue);
        return retValue;
    }

    return 0;
}

static void OnChangedCallback(const CloudDisk_SyncFolderPath syncFolderPath, const CloudDisk_ChangeData changeDatas[], size_t bufferLength)
{
    LogInfo("Path: %{public}s", syncFolderPath.value);
    LogInfo("Length: %{public}d", bufferLength);
    for (int i = 0; i < bufferLength; i++)
    {
        const CloudDisk_ChangeData &data = changeDatas[i];
        LogInfo("  #%{public}d, Seq: %{public}d", i, data.updateSequenceNumber);
        LogInfo("     Id: %{public}s", data.fileId.value);
        LogInfo("     ParentId: %{public}s", data.parentFileId.value);
        LogInfo("     Relative: %{public}s", data.relativePathInfo.value);
        LogInfo("     OP: %{public}s", magic_enum::enum_name<CloudDisk_OperationType>(data.operationType).data());
        LogInfo("     Size: %{public}llu", data.size);
        LogInfo("     MTime: %{public}llu", data.mtime);
    }
}

static napi_value DoConnect(napi_env env, napi_callback_info info)
{
    const auto input = NapiArgs<napi_string>::Get(env, info);
    if (!input.has_value())
        return nullptr;

    const auto [filePath] = *input;
    LogInfo("input: %{public}s", filePath.c_str());

    if (canIUse("SystemCapability.FileManagement.CloudDiskManager"))
    {
        CloudDisk_SyncFolderPath path;
        path.value = strdup(filePath.c_str());
        path.length = filePath.length();
        const auto ret = OH_CloudDisk_ActiveSyncFolder(path);
        LogInfo("returned: %{public}s", magic_enum::enum_name<CloudDisk_ErrorCode>(ret).data());

        OH_CloudDisk_RegisterSyncFolderChanges(path, OnChangedCallback);

        napi_value retValue;
        napi_create_int32(env, ret, &retValue);
        return retValue;
    }

    return 0;
}

static napi_value DoDisconnect(napi_env env, napi_callback_info info)
{
    const auto input = NapiArgs<napi_string>::Get(env, info);
    if (!input.has_value())
        return nullptr;

    const auto [filePath] = *input;
    LogInfo("input: %{public}s", filePath.c_str());

    if (canIUse("SystemCapability.FileManagement.CloudDiskManager"))
    {
        CloudDisk_SyncFolderPath path;
        path.value = strdup(filePath.c_str());
        path.length = filePath.length();
        OH_CloudDisk_UnregisterSyncFolderChanges(path);
        const auto ret = OH_CloudDisk_DeactiveSyncFolder(path);
        LogInfo("returned: %{public}s", magic_enum::enum_name<CloudDisk_ErrorCode>(ret).data());

        napi_value retValue;
        napi_create_int32(env, ret, &retValue);
        return retValue;
    }

    return 0;
}

static napi_value DoRemove(napi_env env, napi_callback_info info)
{
    const auto input = NapiArgs<napi_string>::Get(env, info);
    if (!input.has_value())
        return nullptr;

    const auto [filePath] = *input;

    CloudDisk_SyncFolderPath path;
    path.value = strdup(filePath.c_str());
    path.length = filePath.length();
    const auto ret = OH_CloudDisk_UnregisterSyncFolder(path);
    LogInfo("returned: %{public}s", magic_enum::enum_name<CloudDisk_ErrorCode>(ret).data());

    napi_value retValue;
    napi_create_int32(env, ret, &retValue);
    return retValue;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports)
{
    napi_property_descriptor desc[] = {
        { "add", nullptr, DoAdd, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "remove", nullptr, DoRemove, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "connect", nullptr, DoConnect, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "disconnect", nullptr, DoDisconnect, nullptr, nullptr, nullptr, napi_default, nullptr },
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "cloudsync",
    .nm_priv = ((void *) 0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterCloudSyncModule(void)
{
    napi_module_register(&demoModule);
}
