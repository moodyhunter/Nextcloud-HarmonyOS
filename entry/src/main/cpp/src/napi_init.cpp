#define LOG_TAG "Native"
#include "Logging.hpp"
#include "NapiCallback.hpp"
#include "NapiUtils.hpp"
#include "filemanagement/clouddiskmanager/oh_cloud_disk_manager.h"
#include "include/NapiCallbackStorage.hpp"
#include "magic_enum.hpp"
#include "napi/native_api.h"

using namespace std::chrono_literals;

// #include <syscap_ndk.h>

static bool canIUse(const char *)
{
    return true;
}

struct FileChangeData : public NapiObject
{
    FileChangeData(std::string_view fileId, std::string_view parentId, std::string_view path, CloudDisk_OperationType opType, uint64_t sz, uint64_t mtimeVal)
        : fileId(fileId), parentFileId(parentId), relativePath(path), operationType(opType), size(sz), mtime(mtimeVal)
    {
    }

    std::string_view fileId;
    std::string_view parentFileId;
    std::string_view relativePath;
    CloudDisk_OperationType operationType;
    uint64_t size;
    uint64_t mtime;

    napi_value ToNapiValue(napi_env env) const override
    {
        napi_value obj;
        napi_create_object(env, &obj);

        napi_value napiFileId;
        napi_create_string_utf8(env, fileId.data(), fileId.length(), &napiFileId);
        napi_set_named_property(env, obj, "fileId", napiFileId);

        napi_value napiParentFileId;
        napi_create_string_utf8(env, parentFileId.data(), parentFileId.length(), &napiParentFileId);
        napi_set_named_property(env, obj, "parentFileId", napiParentFileId);

        napi_value napiRelativePath;
        napi_create_string_utf8(env, relativePath.data(), relativePath.length(), &napiRelativePath);
        napi_set_named_property(env, obj, "relativePath", napiRelativePath);

        napi_value napiOperationType;
        napi_create_int32(env, static_cast<int32_t>(operationType), &napiOperationType);
        napi_set_named_property(env, obj, "operationType", napiOperationType);

        napi_value napiSize;
        napi_create_int64(env, static_cast<int64_t>(size), &napiSize);
        napi_set_named_property(env, obj, "size", napiSize);

        napi_value napiMtime;
        napi_create_int64(env, static_cast<int64_t>(mtime), &napiMtime);
        napi_set_named_property(env, obj, "mtime", napiMtime);

        return obj;
    }
};

enum class SyncState
{
    IDLE = CloudDisk_SyncState::IDLE,
    SYNCING = CloudDisk_SyncState::SYNCING,
    SUCCEEDED = CloudDisk_SyncState::SYNC_SUCCEEDED,
    FAILED = CloudDisk_SyncState::SYNC_FAILED,
    CANCELED = CloudDisk_SyncState::SYNC_CANCELED,
    CONFLICTED = CloudDisk_SyncState::SYNC_CONFLICTED,
};

struct SyncFileState
{
    std::string name;
    size_t size;
    SyncState syncState;

    static std::optional<SyncFileState> FromNapiValue(napi_env env, napi_value value)
    {
        if (value == nullptr)
            return std::nullopt;

        // check if is object
        {
            napi_valuetype valueType = napi_undefined;
            napi_typeof(env, value, &valueType);
            if (valueType != napi_object)
                return std::nullopt;
        }

        SyncFileState entry;
        for (const std::string_view prop : { "name", "size", "syncState" })
        {
            napi_value napiProp;
            const auto ret = napi_get_named_property(env, value, prop.data(), &napiProp);
            if (ret != napi_ok)
            {
                LogE("Failed to get property %{public}s", prop.data());
                return std::nullopt;
            }

            if (prop == "name")
            {
                const auto nameOpt = NapiValueConverter<napi_string>::Get(env, napiProp);
                if (!nameOpt.has_value())
                {
                    LogE("Property %{public}s is not a string", prop.data());
                    return std::nullopt;
                }
                entry.name = *nameOpt;
            }
            else if (prop == "size")
            {
                const auto sizeOpt = NapiValueConverter<napi_number>::Get(env, napiProp);
                if (!sizeOpt.has_value())
                {
                    LogE("Property %{public}s is not a number", prop.data());
                    return std::nullopt;
                }
                entry.size = static_cast<size_t>(*sizeOpt);
            }
            else if (prop == "syncState")
            {
                const auto stateOpt = NapiValueConverter<napi_number>::Get(env, napiProp);
                if (!stateOpt.has_value())
                {
                    LogE("Property %{public}s is not a number", prop.data());
                    return std::nullopt;
                }
                entry.syncState = static_cast<SyncState>(*stateOpt);
            }
        }

        return entry;
    }

    std::string ToString() const
    {
        return "SyncFileState{ name: " + name + ", size: " + std::to_string(size) + ", syncState: " + magic_enum::enum_name(syncState).data() + " }";
    }
};

static NapiCallbackStorage<FileChangeData> g_callbackContexts;

static napi_value DoAdd(napi_env env, napi_callback_info info)
{
    const auto input = NapiArgs<napi_string, napi_string>::Get(env, info);
    if (!input.has_value())
        return nullptr;

    const auto [alias, filePath] = *input;
    LogI("input: %{public}s", filePath.c_str());

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

        LogI("returned: %{public}s", magic_enum::enum_name<CloudDisk_ErrorCode>(ret).data());

        napi_value retValue;
        napi_create_int32(env, ret, &retValue);
        return retValue;
    }

    return 0;
}

static void OnChangedCallback(const CloudDisk_SyncFolderPath syncFolderPath, const CloudDisk_ChangeData changeData[], size_t bufferLength)
{
    LogI("received %{public}zu events in %{public}s", bufferLength, syncFolderPath.value);
    for (int i = 0; i < bufferLength; i++)
    {
        const CloudDisk_ChangeData &data = changeData[i];
        const auto change = new FileChangeData{
            std::string_view{ data.fileId.value, data.fileId.length },
            std::string_view{ data.parentFileId.value, data.parentFileId.length },
            std::string_view{ data.relativePathInfo.value, data.relativePathInfo.length },
            data.operationType,
            data.size,
            data.mtime,
        };
        g_callbackContexts.InvokeAll(change);
    }
}

static napi_value DoConnect(napi_env env, napi_callback_info info)
{
    const auto input = NapiArgs<napi_string>::Get(env, info);
    if (!input.has_value())
        return nullptr;

    const auto [filePath] = *input;
    LogI("input: %{public}s", filePath.c_str());

    if (canIUse("SystemCapability.FileManagement.CloudDiskManager"))
    {
        CloudDisk_SyncFolderPath path;
        path.value = strdup(filePath.c_str());
        path.length = filePath.length();
        const auto ret = OH_CloudDisk_ActiveSyncFolder(path);
        LogI("returned: %{public}s", magic_enum::enum_name<CloudDisk_ErrorCode>(ret).data());

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
    LogI("input: %{public}s", filePath.c_str());

    if (canIUse("SystemCapability.FileManagement.CloudDiskManager"))
    {
        CloudDisk_SyncFolderPath path;
        path.value = strdup(filePath.c_str());
        path.length = filePath.length();
        OH_CloudDisk_UnregisterSyncFolderChanges(path);
        const auto ret = OH_CloudDisk_DeactiveSyncFolder(path);
        LogI("returned: %{public}s", magic_enum::enum_name<CloudDisk_ErrorCode>(ret).data());

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
    LogI("returned: %{public}s", magic_enum::enum_name<CloudDisk_ErrorCode>(ret).data());

    napi_value retValue;
    napi_create_int32(env, ret, &retValue);
    return retValue;
}

static napi_value DoRegisterFileChangeMonitor(napi_env env, napi_callback_info info)
{
    const auto input = NapiArgs<napi_function>::Get(env, info);
    if (!input.has_value())
        return nullptr;

    const auto [callback] = *input;
    g_callbackContexts.AddCallback(env, "FileChangeMonitor", callback);
    return nullptr;
}

static napi_value DoSetLocalFileState(napi_env env, napi_callback_info info)
{
    const auto input = NapiArgs<napi_string, napi_object>::Get(env, info);
    if (!input.has_value())
        return nullptr;

    const auto [dirPath, entries] = *input;
    LogI("input: %{public}s", dirPath.c_str());

    std::list<SyncFileState> dirEntries;
    {
        bool isArray = false;
        napi_is_array(env, entries, &isArray);
        if (!isArray)
        {
            LogE("entries is not an array");
            return nullptr;
        }

        uint32_t length = 0;
        napi_get_array_length(env, entries, &length);
        for (uint32_t i = 0; i < length; i++)
        {
            napi_value element;
            napi_get_element(env, entries, i, &element);
            const auto entryOpt = SyncFileState::FromNapiValue(env, element);
            if (!entryOpt.has_value())
            {
                LogE("Failed to parse entry at index %{public}u", i);
                return nullptr;
            }

            LogI("Parsed entry at index %{public}u: %{public}s", i, entryOpt->ToString().c_str());
            dirEntries.push_back(*entryOpt);
        }
    }

    if (canIUse("SystemCapability.FileManagement.CloudDiskManager"))
    {
        CloudDisk_SyncFolderPath path;
        path.value = strdup(dirPath.c_str());
        path.length = dirPath.length();

        std::vector<CloudDisk_FileSyncState> fileSyncStates;
        for (const auto &entry : dirEntries)
        {
            CloudDisk_FileSyncState state;
            state.filePathInfo.value = strdup((dirPath + '/' + entry.name).c_str());
            state.filePathInfo.length = strlen(state.filePathInfo.value);
            state.syncState = static_cast<CloudDisk_SyncState>(entry.syncState);
            fileSyncStates.push_back(state);
        }

        CloudDisk_FailedList *failedLists = nullptr;
        size_t failedCount = 0;
        const auto ret = OH_CloudDisk_SetFileSyncStates(path, fileSyncStates.data(), fileSyncStates.size(), &failedLists, &failedCount);
        LogI("returned: %{public}s", magic_enum::enum_name<CloudDisk_ErrorCode>(ret).data());

        for (size_t i = 0; i < failedCount; i++)
        {
            const CloudDisk_FailedList &failed = failedLists[i];
            std::string failedPath(failed.pathInfo.value, failed.pathInfo.length);
            LogW("Failed to set state for file %{public}s, reason: %{public}s", failedPath.c_str(),
                 magic_enum::enum_name<CloudDisk_ErrorReason>(failed.errorReason).data());
        }

        napi_value retValue;
        napi_create_int32(env, 0, &retValue);
        return retValue;
    }

    return 0;
}

static napi_value DoUpdateCustomAlias(napi_env env, napi_callback_info info)
{
    const auto input = NapiArgs<napi_string, napi_string>::Get(env, info);
    if (!input.has_value())
        return nullptr;

    const auto [filePath, alias] = *input;
    LogI("input: %{public}s, %{public}s", filePath.c_str(), alias.c_str());

    if (canIUse("SystemCapability.FileManagement.CloudDiskManager"))
    {
        CloudDisk_SyncFolderPath path;
        path.value = strdup(filePath.c_str());
        path.length = filePath.length();

        const auto ret = OH_CloudDisk_UpdateCustomAlias(path, alias.c_str(), alias.length());

        LogI("returned: %{public}s", magic_enum::enum_name<CloudDisk_ErrorCode>(ret).data());

        napi_value retValue;
        napi_create_int32(env, ret, &retValue);
        return retValue;
    }

    return 0;
}

static napi_value Init(napi_env env, napi_value exports)
{
    const napi_property_descriptor desc[] = {
        { "add", nullptr, DoAdd, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "remove", nullptr, DoRemove, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "connect", nullptr, DoConnect, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "disconnect", nullptr, DoDisconnect, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "registerFileChangeMonitor", nullptr, DoRegisterFileChangeMonitor, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setLocalFileState", nullptr, DoSetLocalFileState, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "updateCustomAlias", nullptr, DoUpdateCustomAlias, nullptr, nullptr, nullptr, napi_default, nullptr },
    };

    // add methods to export
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);

    return exports;
}

NAPI_MODULE_X(cloudsync, Init, nullptr, 0)
