import { DBLocalSyncFolder, LocalFolderType } from "../DbTypes/DBLocalFolder";

export class LocalFolder {
    private dbLocalFolder_: DBLocalSyncFolder;

    constructor(dbLocalFolder: DBLocalSyncFolder) {
        this.dbLocalFolder_ = dbLocalFolder;
    }

    public get id(): number {
        return this.dbLocalFolder_.id;
    }

    public get folderType(): LocalFolderType {
        return this.dbLocalFolder_.folderType;
    }

    // only valid for regular folder type
    public get localPath(): string {
        if (this.dbLocalFolder_.folderType === LocalFolderType.Regular) {
            return this.dbLocalFolder_.localPath;
        } else {
            return "";
        }
    }

    // only valid for albums
    public get albumId(): number {
        if (this.dbLocalFolder_.folderType === LocalFolderType.PhotoAlbum) {
            return Number(this.dbLocalFolder_.localPath);
        } else {
            return 0;
        }
    }

    public get alias(): string {
        return this.dbLocalFolder_.alias;
    }
}
