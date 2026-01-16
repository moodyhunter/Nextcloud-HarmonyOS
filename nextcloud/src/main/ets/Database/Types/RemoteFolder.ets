import { Account } from '../../Account/Account';
import { DBRemoteFolder } from '../DbTypes/DBRemoteFolder';

export class RemoteFolder {
    private dbRemoteFolder_: DBRemoteFolder;

    constructor(dbRemoteFolder: DBRemoteFolder) {
        this.dbRemoteFolder_ = dbRemoteFolder;
    }

    public get id(): number {
        return this.dbRemoteFolder_.id;
    }

    public get remotePath(): string {
        return this.dbRemoteFolder_.remotePath;
    }
}
