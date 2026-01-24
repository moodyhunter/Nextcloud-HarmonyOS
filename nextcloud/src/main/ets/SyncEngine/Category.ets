import { Logger } from '../Utils/Logger';
import { ImageListDataSource } from './ImageListDataSource';
import {
    PhotoItem,
    UploadResult
} from './PhotoItem';
import { promptAction } from '@kit.ArkUI';
import { NCommon } from '../Common';
import { LocalFolder } from '../Database/Types/LocalFolder';
import { LocalFolderType } from '../Database/DbTypes/DBLocalFolder';
import { PhotoAssetsManager } from './PhotoAssetsManager';

const TAG = 'models/Category';

export enum AddAssetResult {
    Added,
    Unmatched,
    Throttled
}

export enum AddPosition {
    Append,
    Prepend
}

const IMAGE_LIST_MAX_ITEMS = 50;

@Observed
export class Category {
    private localFolder: LocalFolder;
    /**
     * Items that are currently visible on the UI (not all assets are listed for performance reason)
     */
    visibleItems: ImageListDataSource = new ImageListDataSource();

    constructor(localFolder: LocalFolder) {
        if (localFolder.folderType !== LocalFolderType.PhotoAlbum) {
            throw Error('local folder type incorrect');
        }
        this.localFolder = localFolder;
        this.loadNextBatch();
    }

    public get name() {
        return this.localFolder.alias;
    }

    tryAddAsset(asset: PhotoItem, position: AddPosition): AddAssetResult {
        if (!this.matchesAsset(asset)) {
            return AddAssetResult.Unmatched;
        }

        switch (position) {
            case AddPosition.Append: {
                this.visibleItems.addAsset(asset);
                return AddAssetResult.Added;
            }
            case AddPosition.Prepend: {
                this.visibleItems.prependAsset(asset);
                return AddAssetResult.Added;
            }
        }
    }

    async loadNextBatch(): Promise<void> {
        const offset = this.visibleItems.totalCount();
        let items = await PhotoAssetsManager.loadNextBatchFromAlbumId(this.localFolder.albumId, offset, 50);
        for (let item of items) {
            this.visibleItems.addAsset(item);
        }
    }

    getAssets(start: number, length: number): PhotoItem[] {
        let result: PhotoItem[] = [];
        // Get from items if it's completely within range
        if (start + length <= this.visibleItems.totalCount()) {
            result = this.visibleItems.getDataRange(start, length);
        } else if (start >= this.visibleItems.totalCount()) {
            // Get from backedItems if it's completely within backedItems
            let backedStart = start - this.visibleItems.totalCount();
            // for (let i = backedStart; i < Math.min(backedStart + length, this.invisibleBackedItems.size); i++) {
            // result.push(this.invisibleBackedItems[i]);
            // }
        } else {
            // Get from both items and backedItems
            let itemsPartLength = this.visibleItems.totalCount() - start;
            result = this.visibleItems.getDataRange(start, itemsPartLength);
            let backedPartLength = length - itemsPartLength;
            // for (let i = 0; i < Math.min(backedPartLength, this.invisibleBackedItems.size); i++) {
            // result.push(this.invisibleBackedItems[i]);
            // }
        }
        return result;
    }

    // getTotalAvailableCount(): number {
    //     return this.visibleItems.totalCount() + this.invisibleBackedItems.size;
    // }
    //
    //     async uploadAllAssets(notify: boolean = true) {
    //         const BATCH_SIZE = 8;
    //         // const totalCount = this.getTotalAvailableCount();
    //         // let total = Math.ceil(totalCount / BATCH_SIZE) * BATCH_SIZE;
    //         let totalUploaded = 0;
    //         for (let i = 0; i < total; i += BATCH_SIZE) {
    //             let batch = this.getAssets(i, BATCH_SIZE);
    //
    //             let canStop = true;
    //             //
    //             //             let futures = batch.map(asset => {
    //             //                 return asset.upload(NCommon.Preference.baseUploadDirectory + this.location).then((result) => {
    //             //                     canStop = canStop && result === UploadResult.EXISTED;
    //             //                     totalUploaded++;
    //             //                 }).then(() => {
    //             //                     if (notify) {
    //             //                         // NotificationManager.publishNotification('title', 'content', 1);
    //             //                     }
    //             //                 });
    //             //             });
    //
    //             // await Promise.all(futures);
    //             // if (canStop) {
    //             //     if (notify) {
    //             //         // NotificationManager.publishNotification('title', 'content', 1);
    //             //     }
    //             //     promptAction.showToast({
    //             //         message: `Upload is probably completed`,
    //             //         duration: 2000,
    //             //     });
    //             //     break;
    //             // }
    //         }
    // }

    private matchesAsset(asset: PhotoItem): boolean {
        return asset.ownerAlbumId === this.localFolder.id;
    }
}
