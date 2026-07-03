import { AccountConfig, DBAccount } from '../Database/DbTypes/DBAccount';
import { RemoteFolder } from '../Database/Types/RemoteFolder';
import { Nextcloud } from '../Main';
import { Base64Encode } from '../Utils/CommonUtils';
import { Logger } from '../Utils/Logger';

const TAG = 'Account/Account';

export class Account {
    public dbAccount: DBAccount;

    constructor(dbAccount: DBAccount) {
        Logger.Info(TAG, `constructor: enter`);
        this.dbAccount = dbAccount;
    }

    public get id(): number {
        return this.dbAccount.id;
    }

    public get username(): string {
        return this.dbAccount.username;
    }

    public get hostname(): string {
        return this.dbAccount.hostname;
    }

    private get baseUrlWithCredentials(): string {
        return `https://${this.dbAccount.username}:${this.dbAccount.password}@${this.dbAccount.hostname}`;
    }

    public static createNewAccount(hostname: string, username: string, password: string): Account {
        Logger.Info(TAG, `createNewAccount: enter, hostname=${hostname}, username=${username}`);
        const accountConfig: AccountConfig = {
            instantUploadFolderId: 0,
        }
        let dbAccount = new DBAccount(0, hostname, username, password, accountConfig);
        return new Account(dbAccount);
    }

    public isLoggedIn(): boolean {
        return this.dbAccount.password !== '';
    }

    public makeAuthorizationHeader(): string {
        return 'basic ' + Base64Encode(this.dbAccount.username + ":" + this.dbAccount.password);
    }

    public remoteBaseDirUrl(): string {
        return `https://${this.dbAccount.hostname}/remote.php/dav/files/${this.dbAccount.username}/`;
    }

    public chunkedUploadBaseUrl(): string {
        return `https://${this.dbAccount.hostname}/remote.php/dav/uploads/${this.dbAccount.username}/`;
    }

    public getPreviewUrl(fileId: string, x: number = 64, y: number = 64): string {
        return this.baseUrlWithCredentials + `/core/preview?fileId=${fileId}&x=${x}&y=${y}&mimeFallback=true`;
    }

    public getDownloadUrl(path: string): string {
        let encodedPath = encodeURI(path);
        return this.baseUrlWithCredentials + `/remote.php/dav/files/${this.dbAccount.username}/${encodedPath}`;
    }

    public async getRemoteUploadFolder(): Promise<RemoteFolder | null> {
        if (this.dbAccount.config.instantUploadFolderId === 0) {
            Logger.Info(TAG, `account did not have instant upload configured`);
            return null;
        }
        let remoteFolder = await Nextcloud.getSyncFolderManager().getRemoteFolderById(this.dbAccount.config.instantUploadFolderId);
        if (remoteFolder === null) {
            Logger.Error(TAG, `failed to get remote folder`);
            return null;
        }

        if (remoteFolder.accountId !== this.id) {
            Logger.Error(TAG, `remote folder accountId mismatches, ${remoteFolder.accountId} vs ${this.id}`)
            this.dbAccount.config.instantUploadFolderId = 0;
            return null;
        }

        return remoteFolder;
    }
}
