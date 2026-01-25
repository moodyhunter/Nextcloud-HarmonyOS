import { ImageListDataSource } from './ImageListDataSource';
import { PhotoItem } from './PhotoItem';
import { LocalFolder } from '../Database/Types/LocalFolder';
import { LocalFolderType } from '../Database/DbTypes/DBLocalFolder';
import { PhotoAssetsManager } from './PhotoAssetsManager';
import { Logger } from '../Utils/Logger';

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

const BATCH_SIZE = 150;

export class Category {
    visibleItems: ImageListDataSource = new ImageListDataSource();
    localFolder: LocalFolder;

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

    public get instantUploadEnabled() {
        return this.localFolder.dbLocalFolder.config.instantUploadEnabled;
    }

    public setAlias(newAlias: string) {
        this.localFolder.alias = newAlias;
    }

    tryAddAsset(asset: PhotoItem, position: AddPosition): AddAssetResult {
        if (!this.matchesAsset(asset)) {
            Logger.Error(TAG, `tryAddAsset: asset albumId ${asset.ownerAlbumId} doesn't match category albumId ${this.localFolder.albumId}`);
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
            default: {
                Logger.Error(TAG, `tryAddAsset: unknown position ${position}`);
                return AddAssetResult.Unmatched;
            }
        }
    }

    async loadNextBatch(): Promise<void> {
        const offset = this.visibleItems.totalCount();
        let items = await PhotoAssetsManager.loadNextBatchFromAlbumId(this.localFolder.albumId, offset, BATCH_SIZE);
        for (let item of items) {
            this.visibleItems.addAsset(item);
        }
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
        return asset.ownerAlbumId === this.localFolder.albumId;
    }
}
