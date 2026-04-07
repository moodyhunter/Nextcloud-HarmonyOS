import { ImageListDataSource } from './ImageListDataSource';
import { PhotoItem, UploadStatus } from './PhotoItem';
import { LocalFolder } from '../Database/Types/LocalFolder';
import { LocalFolderType } from '../Database/DbTypes/DBLocalFolder';
import { PhotoAssetsManager } from './PhotoAssetsManager';
import { Logger } from '../Utils/Logger';
import { RemoteFolder } from '../Database/Types/RemoteFolder';
import { CreateSession, IsRemotePathExists } from '../webdav/TransferUtils';

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

const BATCH_SIZE = 75;

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

    public set instantUploadEnabled(value: boolean) {
        this.localFolder.dbLocalFolder.config.instantUploadEnabled = value;
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

    async loadNextBatch(): Promise<number> {
        const offset = this.visibleItems.totalCount();
        try {
            let items = await PhotoAssetsManager.loadNextBatchFromAlbumId(this.localFolder.albumId, offset, BATCH_SIZE);
            for (let item of items) {
                this.visibleItems.addAsset(item);
            }
            return items.length;
        } catch (error) {
            Logger.Error(TAG, `loadNextBatch: failed: ${JSON.stringify(error)}`);
            return 0;
        }
    }

    public async uploadAllAssets(remoteFolder: RemoteFolder): Promise<void> {
        const BATCH_SIZE = 16;
        Logger.Info(TAG, `uploadAllAssets: enter`);

        let jobs: Promise<void>[] = [];
        let totalCount = this.visibleItems.totalCount();
        let i = 0;
        let continuesExistance = 0;
        while (true) {
            // to the current end
            if (i === totalCount) {
                const nextBatchSize = await this.loadNextBatch();
                if (nextBatchSize === 0) {
                    Logger.Info(TAG, `uploadAllAssets: reached to the end`);
                    break;
                }
                Logger.Info(TAG, `uploadAllAssets: continue from ${i} to ${totalCount}+${nextBatchSize}`);
                totalCount = this.visibleItems.totalCount();
            }
            Logger.Info(TAG, `uploadAllAssets: checking for ${i}/${totalCount} photo item`);
            const photoItem = this.visibleItems.getData(i++);
            photoItem.uploadStatus = UploadStatus.Pending;
            const uploadData = photoItem.getUploadJobData(this.name, remoteFolder);
            const fullRemotePath = '/' + remoteFolder.remotePath + '/' + uploadData.relativePath + '/' + uploadData.fileName;

            let exists: boolean;
            {
                const rcpSession = CreateSession(remoteFolder.account);
                exists = await IsRemotePathExists(rcpSession, remoteFolder.account, fullRemotePath);
                rcpSession.close();
            }
            Logger.Info(TAG, `uploadAllAssets: relative path '${fullRemotePath}' exists: ${exists}`);

            if (exists) {
                continuesExistance++;
                photoItem.uploadStatus = UploadStatus.Existed;
                if (continuesExistance === BATCH_SIZE) {
                    Logger.Info(TAG, `uploadAllAssets: last ${BATCH_SIZE} exists, complete`);
                    break;
                }
            } else {
                continuesExistance = 0;
                photoItem.uploadStatus = UploadStatus.Pending;
                let job = photoItem.getUploadJob(this.name, remoteFolder);
                await job.start();
            }
        }
    }

    private matchesAsset(asset: PhotoItem): boolean {
        return asset.ownerAlbumId === this.localFolder.albumId;
    }
}
