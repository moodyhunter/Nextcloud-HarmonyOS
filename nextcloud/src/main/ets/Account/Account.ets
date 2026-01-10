import { DBAccount } from '../Database/Types/DBAccount';
import { Base64Encode } from '../Utils/CommonUtils';
import { Logger } from '../Utils/Logger';

const TAG = 'Account/Account';

export class Account extends DBAccount {
    constructor(dbAccount: DBAccount) {
        Logger.Info(TAG, `constructor: enter`);
        super(dbAccount.id, dbAccount.hostname, dbAccount.username, dbAccount.password);
    }

    private get baseUrlWithCredentials(): string {
        return `https://${this.username}:${this.password}@${this.hostname}`;
    }

    public static createNewAccount(hostname: string, username: string, password: string): Account {
        Logger.Info(TAG, `createNewAccount: enter, hostname=${hostname}, username=${username}`);
        let dbAccount = new DBAccount(0, hostname, username, password);
        return new Account(dbAccount);
    }

    public isLoggedIn(): boolean {
        return this.password !== '';
    }

    public makeAuthorizationHeader(): string {
        return 'basic ' + Base64Encode(this.username + ":" + this.password);
    }

    public remoteBaseDirUrl(): string {
        return `https://${this.hostname}/remote.php/dav/files/${this.username}/`;
    }

    public getPreviewUrl(fileId: string, x: number = 64, y: number = 64): string {
        return this.baseUrlWithCredentials + `/core/preview?fileId=${fileId}&x=${x}&y=${y}&mimeFallback=true`;
    }

    public getDownloadUrl(path: string): string {
        let encodedPath = encodeURI(path);
        return this.baseUrlWithCredentials + `/remote.php/dav/files/${this.username}/${encodedPath}`;
    }
}
