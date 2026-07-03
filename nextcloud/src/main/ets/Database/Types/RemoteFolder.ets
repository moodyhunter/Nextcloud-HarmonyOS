import { Account } from '../../Account/Account';
import { DBRemoteFolder } from '../DbTypes/DBRemoteFolder';

export class RemoteFolder {
    private dbRemoteFolder_: DBRemoteFolder;
    private account_: Account;

    constructor(account: Account, dbRemoteFolder: DBRemoteFolder) {
        this.dbRemoteFolder_ = dbRemoteFolder;
        this.account_ = account;
    }

    public get name() {
        return this.dbRemoteFolder_.alias;
    }

    public get id(): number {
        return this.dbRemoteFolder_.id;
    }

    public get accountId(): number {
        return this.dbRemoteFolder_.accountId;
    }

    public get account(): Account {
        return this.account_;
    }

    public get remotePath(): string {
        return this.dbRemoteFolder_.remotePath;
    }

    public getFullPath(relativePath: string): string {
        let basePath = this.remotePath;
        if (!basePath.endsWith('/')) {
            basePath += '/';
        }
        return basePath + relativePath;
    }
}
