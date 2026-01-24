import { DBLocalSyncFolder, LocalFolderType } from "../DbTypes/DBLocalFolder";
import { LocalFolder } from "./LocalFolder";

export class LocalAlbumFolder extends LocalFolder {
    constructor(dbLocalFolder: DBLocalSyncFolder) {
        super(dbLocalFolder);
        if (dbLocalFolder.folderType !== LocalFolderType.PhotoAlbum) {
            throw Error("LocalAlbumFolder must be of PhotoAlbum type");
        }
    }
}
