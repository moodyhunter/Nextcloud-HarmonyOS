import { DBLocalFolder, LocalFolderType } from '../DbTypes/DBLocalFolder';

export class LocalFolder {
    private dbLocalFolder_: DBLocalFolder;

    constructor(dbLocalFolder: DBLocalFolder) {
        this.dbLocalFolder_ = dbLocalFolder;
    }

    public get id(): number {
        return this.dbLocalFolder_.id;
    }

    public get dbLocalFolder() {
        return this.dbLocalFolder_;
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

    public set alias(newAlias: string) {
        this.dbLocalFolder_.alias = newAlias;
    }

    public getFullPath(relativePath: string): string {
        if (this.dbLocalFolder_.folderType === LocalFolderType.Regular) {
            if (this.localPath.endsWith('/')) {
                return this.localPath + relativePath;
            } else {
                return this.localPath + '/' + relativePath;
            }
        } else {
            return "";
        }
    }
}
