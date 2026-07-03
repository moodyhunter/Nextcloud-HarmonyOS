import { rcp } from '@kit.RemoteCommunicationKit';
import { NCommon } from '../Common';
import { Logger } from '../Utils/Logger';
import { Account } from '../Account/Account';

const TAG = "webdav/Upload";

export function CreateSession(
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
                verbose: true,
                infoToCollect: {
                    textual: true,
                    incomingHeader: true,
                    outgoingHeader: true,
                    incomingData: true,
                    outgoingData: true,
                    incomingSslData: true,
                    outgoingSslData: true
                },
                collectTimeInfo: true,
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

export async function IsRemotePathExists(
    session: rcp.Session,
    account: Account,
    path: string): Promise<boolean> {
    let fullPath = account.remoteBaseDirUrl() + path;
    Logger.Info(TAG, `IsRemotePathExists: checking if path exists: '${fullPath}'`);

    try {
        let resp = await session.fetch(new rcp.Request(fullPath, "HEAD", {}));
        if (resp.statusCode === 200 || resp.statusCode === 207) {
            Logger.Info(TAG, "IsRemotePathExists: Path exists: " + fullPath);
            return true;
        } else if (resp.statusCode === 404) {
            Logger.Info(TAG, "IsRemotePathExists: Path does not exist: " + fullPath);
            return false;
        } else {
            Logger.Error(TAG, "IsRemotePathExists: Failed to check path existence: " + resp.statusCode);
            return false;
        }
    } catch (e) {
        Logger.Error(TAG, "IsRemotePathExists: failed: " + e);
        return false;
    }
}

export async function CreatePath(account: Account, path: string): Promise<number> {
    let session = CreateSession(account);
    if (await IsRemotePathExists(session, account, path)) {
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
