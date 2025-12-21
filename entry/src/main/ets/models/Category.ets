import { Logger, NCommon } from 'nextcloud';
import { ImageListDataSource } from './ImageListDataSource';
import { PhotoItem, UploadResult } from './PhotoItem';
import { promptAction } from '@kit.ArkUI';
import { Notification } from '../utils/NotificationManager';

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
export class Category implements NCommon.CategoryConfig {
    name: string;
    patterns: string[];
    location: string;
    /**
     * Items that are currently visible on the UI (not all assets are listed for performance reason)
     */
    visibleItems: ImageListDataSource = new ImageListDataSource();
    invisibleBackedItems: Map<string, PhotoItem> = new Map<string, PhotoItem>();

    constructor(other: NCommon.CategoryConfig) {
        this.name = other.name;
        this.patterns = other.patterns;
        this.location = other.location;
    }

    tryAddAsset(asset: PhotoItem, position: AddPosition): AddAssetResult {
        if (!this.matchesAsset(asset)) {
            return AddAssetResult.Unmatched;
        }

        switch (position) {
            case AddPosition.Append: {
                if (this.visibleItems.totalCount() > IMAGE_LIST_MAX_ITEMS) {
                    this.invisibleBackedItems.set(asset.uri, asset);
                    return AddAssetResult.Throttled;
                } else {
                    this.visibleItems.addAsset(asset);
                    return AddAssetResult.Added;
                }
            }
            case AddPosition.Prepend: {
                this.visibleItems.prependAsset(asset);
                return AddAssetResult.Added;
            }
        }
    }

    showNext50(): void {
        Logger.Info(TAG, `loadNext50 enter`);
        let count = 0;
        while (this.invisibleBackedItems.size > 0 && count < 50) {
            let asset = this.invisibleBackedItems.values().next().value as PhotoItem;
            this.invisibleBackedItems.delete(asset.uri);
            this.visibleItems.addAsset(asset);
            count++;
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
            for (let i = backedStart; i < Math.min(backedStart + length, this.invisibleBackedItems.size); i++) {
                result.push(this.invisibleBackedItems[i]);
            }
        } else {
            // Get from both items and backedItems
            let itemsPartLength = this.visibleItems.totalCount() - start;
            result = this.visibleItems.getDataRange(start, itemsPartLength);
            let backedPartLength = length - itemsPartLength;
            for (let i = 0; i < Math.min(backedPartLength, this.invisibleBackedItems.size); i++) {
                result.push(this.invisibleBackedItems[i]);
            }
        }
        return result;
    }

    getTotalAvailableCount(): number {
        return this.visibleItems.totalCount() + this.invisibleBackedItems.size;
    }

    async uploadAllAssets(notify: boolean = true) {
        const BATCH_SIZE = 8;
        const totalCount = this.getTotalAvailableCount();
        let total = Math.ceil(totalCount / BATCH_SIZE) * BATCH_SIZE;
        let totalUploaded = 0;
        for (let i = 0; i < total; i += BATCH_SIZE) {
            let batch = this.getAssets(i, BATCH_SIZE);

            let canStop = true;

            let futures = batch.map(asset => {
                return asset.upload(NCommon.Preference.baseUploadDirectory + this.location).then((result) => {
                    canStop = canStop && result === UploadResult.EXISTED;
                    totalUploaded++;
                }).then(() => {
                    if (notify) {
                        Notification.publishUploadProgress(totalUploaded, totalCount)
                    }
                });
            });

            await Promise.all(futures);
            if (canStop) {
                if (notify) {
                    Notification.publishIdleNotification();
                }
                promptAction.showToast({
                    message: `Upload is probably completed`,
                    duration: 2000,
                });
                break;
            }
        }
    }

    private matchesAsset(asset: PhotoItem): boolean {
        for (let p of this.patterns) {
            if (RegExp(p).test(asset.displayName)) {
                return true;
            }
        }
        return false;
    }
}
