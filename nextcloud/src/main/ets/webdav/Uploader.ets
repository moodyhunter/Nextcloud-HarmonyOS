import { rcp } from '@kit.RemoteCommunicationKit';
import { NCommon } from '../Common';
import fs from '@ohos.file.fs';
import { Logger } from '../Utils/Logger';
import { TransferManager } from '../SyncEngine/TransferManager';
import { Account } from '../Account/Account';
import { TransferType } from '../SyncEngine/TransferManagerEventIPC';

const TAG = "webdav/Upload";

function CreateSession(
    account: Account,
    extraHeaders?: Map<string, string>,
    eventsHandler?: rcp.HttpEventsHandler): rcp.Session {
    let headers: rcp.RequestHeaders = {};

    if (extraHeaders !== undefined) {
        for (let item of extraHeaders) {
            headers[item[0]] = item[1];
        }
    }

    headers['authorization'] = account.makeAuthorizationHeader();
    headers['user-agent'] = NCommon.UserAgent();
    headers['accept'] = 'text/plains';

    let sessionConfiguration: rcp.SessionConfiguration = {
        headers: headers,
        requestConfiguration: {
            tracing: {
                httpEventsHandler: eventsHandler,
            }
        }
    }

    try {
        return rcp.createSession(sessionConfiguration);
    } catch (error) {
        Logger.Error(TAG, `failed to create session: ${JSON.stringify(error)}`);
        throw error as Error;
    }
}

export async function Exists(
    session: rcp.Session,
    account: Account,
    path: string,
    filename: string = ""): Promise<boolean> {
    let fullPath = account.remoteBaseDirUrl() + path + "/" + filename;
    Logger.Info(TAG, "Checking if path exists: " + fullPath);

    try {
        let resp = await session.fetch(new rcp.Request(fullPath, "HEAD", {}));
        if (resp.statusCode === 200 || resp.statusCode === 207) {
            Logger.Info(TAG, "Path exists: " + fullPath);
            return true;
        } else if (resp.statusCode === 404) {
            Logger.Info(TAG, "Path does not exist: " + fullPath);
            return false;
        } else {
            Logger.Error(TAG, "Failed to check path existence: " + resp.statusCode);
            return false;
        }
    } catch (e) {
        Logger.Error(TAG, "Error checking path existence: " + e);
        return false;
    }
}

export async function CreatePath(account: Account, path: string): Promise<number> {
    let session = CreateSession(account);
    if (await Exists(session, account, path)) {
        Logger.Info(TAG, "Path already exists: " + path);
        session.close();
        return 201;
    }

    let segment = path.split("/");
    let respCode = -1;
    for (let i = 0; i < segment.length; i++) {
        let thisLevel = segment.slice(0, i + 1).join("/");
        if (!thisLevel) {
            continue;
        }
        let fullPath = account.remoteBaseDirUrl() + thisLevel + "/";
        try {
            let resp = await session.fetch(new rcp.Request(fullPath, "MKCOL", {}));
            Logger.Info(TAG, `Create path '${thisLevel}', response: ${resp.statusCode}`);
            respCode = resp.statusCode;
            if (resp.statusCode !== 201 && resp.statusCode !== 405) {
                Logger.Error(TAG, "Failed to create path: " + resp.statusCode);
                session.close();
                return resp.statusCode;
            }
        } catch (e) {
            Logger.Error(TAG, "Failed to create path: " + e);
            session.close();
            return respCode;
        }
    }
    session.close();
    return respCode;
}

export async function DownloadFile(account: Account, relativePath: string, localPath: string): Promise<void> {
    let parts = relativePath.split('/');
    let task = TransferManager.addTransferTask(TransferType.DOWNLOAD, parts[parts.length - 1]);

    let transferredSize = 0;
    let totalSize = 0;

    let timerId = setInterval(() => {
        task.updateProgress(transferredSize, totalSize);
    }, 500);

    let eventsHandler: rcp.HttpEventsHandler = {
        onDownloadProgress: (totalBytes: number, transferredBytes: number) => {
            transferredSize = transferredBytes;
            totalSize = totalBytes;
        }
    };

    let session = CreateSession(account, undefined, eventsHandler);
    let downloadToFileOptions: rcp.DownloadToFile = {
        kind: "file",
        file: localPath,
    };

    await session.downloadToFile(account.remoteBaseDirUrl() + relativePath, downloadToFileOptions).then(() => {
        clearInterval(timerId);
        task.updateProgress(totalSize, totalSize);
    }).catch((error: BusinessError) => {
        Logger.Error(TAG, `Download failed: ${relativePath}, error: ${JSON.stringify(error)}`);
    });
    clearInterval(timerId);
    session.close();
}

export async function UploadFile(
    account: Account,
    filename: string,
    mTime: number,
    path: string,
    uri: string): Promise<number> {
    let extraHeaders = new Map<string, string>();
    extraHeaders.set('X-OC-MTime', `${Math.round(mTime / 1000)}`);
    let session = CreateSession(account, extraHeaders);

    if (!NCommon.Preference.replaceExistingFiles) {
        if (await Exists(session, account, path, filename)) {
            Logger.Info(TAG, `file already exists: ${filename}, not replacing as per settings`);
            session.close();
            return 204; // No Content, file already exists
        }
    }


    let file: fs.File;
    try {
        file = await fs.open(uri);
        Logger.Debug(TAG, "File opened");
    } catch (error) {
        Logger.Error(TAG, `failed to create readonly file: ${JSON.stringify(error)}`);
        throw error as Error;
    }

    let fullpath = account.remoteBaseDirUrl() + path + "/" + filename;
    Logger.Info(TAG, "Uploading file to " + fullpath);

    let ret = -1;
    try {
        let resp = await session.put(fullpath, new rcp.UploadFromFile(file));
        Logger.Info(TAG, "Upload response: " + resp.statusCode);
        ret = resp.statusCode;
    } catch (e) {
        Logger.Error(TAG, "Failed to upload file: " + e);
    }

    try {
        await fs.close(file);
    } catch (error) {
        Logger.Warn(TAG, `failed to close the file: ${JSON.stringify(error)}`);
    }
    session.close();
    return ret;
}
