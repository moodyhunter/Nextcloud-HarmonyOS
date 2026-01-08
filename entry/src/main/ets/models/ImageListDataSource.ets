import { BasicDataSource } from 'nextcloud';
import { PhotoItem } from './PhotoItem';


export class ImageListDataSource extends BasicDataSource<PhotoItem> {
    constructor() {
        super();
    }

    public prependAsset(asset: PhotoItem) {
        this.prependItem(asset);
    }

    public addAsset(asset: PhotoItem) {
        this.appendItem(asset);
    }

    public addWithoutNotify(asset: PhotoItem) {
        this.entries.push(asset);
    }
}
