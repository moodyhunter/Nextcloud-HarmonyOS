import { DBLocalFolder, LocalFolderType } from "../DbTypes/DBLocalFolder";
import { LocalFolder } from "./LocalFolder";

export class LocalAlbumFolder extends LocalFolder {
    constructor(dbLocalFolder: DBLocalFolder) {
        super(dbLocalFolder);
        if (dbLocalFolder.folderType !== LocalFolderType.PhotoAlbum) {
            throw Error("LocalAlbumFolder must be of PhotoAlbum type");
        }
    }
}
