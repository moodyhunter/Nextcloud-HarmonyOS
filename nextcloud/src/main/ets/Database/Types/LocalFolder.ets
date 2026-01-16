import { DBLocalSyncFolder } from "../DbTypes/DBLocalFolder";

export class LocalFolder {
    private dbLocalFolder_: DBLocalSyncFolder;

    constructor(dbLocalFolder: DBLocalSyncFolder) {
        this.dbLocalFolder_ = dbLocalFolder;
    }

    public get id(): number {
        return this.dbLocalFolder_.id;
    }

    public get localPath(): string {
        return this.dbLocalFolder_.localPath;
    }

    public get alias(): string {
        return this.dbLocalFolder_.alias;
    }
}
