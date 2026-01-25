import { AddPosition, Category } from './Category';
import { PhotoItem } from './PhotoItem';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { dataSharePredicates } from '@kit.ArkData';
import { LocalFolder } from '../Database/Types/LocalFolder';
import { LocalFolderType } from '../Database/DbTypes/DBLocalFolder';
import { Nextcloud } from '../Main';
import { NCommon } from '../Common';
import { Logger } from '../Utils/Logger';

const TAG = 'Utils/PhotoAssetsManager';

@ObservedV2
class PhotoAssetsManagerImpl {
    private static readonly FETCH_COLUMNS = [
        photoAccessHelper.PhotoKeys.URI,
        photoAccessHelper.PhotoKeys.PHOTO_TYPE,
        photoAccessHelper.PhotoKeys.PHOTO_SUBTYPE,
        photoAccessHelper.PhotoKeys.DISPLAY_NAME,
        photoAccessHelper.PhotoKeys.DATE_TAKEN,
        photoAccessHelper.PhotoKeys.DATE_ADDED_MS,
        photoAccessHelper.PhotoKeys.SIZE,
        photoAccessHelper.PhotoKeys.WIDTH,
        photoAccessHelper.PhotoKeys.HEIGHT,
        photoAccessHelper.PhotoKeys.TITLE,
        photoAccessHelper.PhotoKeys.COVER_POSITION,
        photoAccessHelper.PhotoKeys.DYNAMIC_RANGE_TYPE,
        photoAccessHelper.PhotoKeys.DETAIL_TIME,
        photoAccessHelper.PhotoKeys.DATE_TAKEN_MS,
        photoAccessHelper.PhotoKeys.OWNER_ALBUM_ID,
    ];
    @Trace public categories: Map<number, Category> = new Map();

    /**
     * @throws
     * @returns
     */
    public async loadNextBatchFromAlbumId(albumId: number, offset: number, limit: number): Promise<PhotoItem[]> {
        const FETCH_OPTIONS: photoAccessHelper.FetchOptions = {
            fetchColumns: PhotoAssetsManagerImpl.FETCH_COLUMNS,
            predicates: new dataSharePredicates.DataSharePredicates()
                .equalTo(photoAccessHelper.PhotoKeys.OWNER_ALBUM_ID, albumId.toString())
                .orderByDesc(photoAccessHelper.PhotoKeys.DATE_TAKEN)
                .limit(limit, offset)
        };

        let result = await NCommon.pHelper.getAssets(FETCH_OPTIONS);
        let assets = await result.getAllObjects();
        Logger.Debug(TAG, `loadNextBatchFromAlbumId:` +
            `albumId: ${albumId}`,
            `offset: ${offset}`,
            `limit: ${limit} -> ${assets.length} assets`
        );
        let items: PhotoItem[] = [];
        for (let asset of assets) {
            items.push(new PhotoItem(asset));
        }
        return items;
    }

    public async initialize(categories: Map<number, LocalFolder>) {
        for (let item of categories) {
            let localFolder = item[1];
            if (localFolder.folderType === LocalFolderType.PhotoAlbum) {
                this.categories.set(localFolder.albumId, new Category(localFolder));
            }
        }

        const sfm = Nextcloud.getSyncFolderManager();
        const albums = await this.getAllCategories();
        for (let albumId of albums) {
            if (!this.categories.has(albumId)) {
                Logger.Warn(TAG, `initialize: found new AlbumId: ${albumId}`);
                let localFolder = await sfm.addLocalAlbumFolder(albumId, `Album ${albumId}`);
                this.categories.set(localFolder.albumId, new Category(localFolder));
            }
        }
    }

    public async prependNewAsset(assetUri: string) {
        Logger.Info(TAG, `prependNewAsset enter, uri: ${assetUri}`);
        const FETCH_OPTIONS: photoAccessHelper.FetchOptions = {
            fetchColumns: PhotoAssetsManagerImpl.FETCH_COLUMNS,
            predicates: new dataSharePredicates.DataSharePredicates()
                .equalTo(photoAccessHelper.PhotoKeys.URI, assetUri),
        };

        try {
            let assetResult = await NCommon.pHelper.getAssets(FETCH_OPTIONS);
            if (assetResult.getCount() !== 1) {
                Logger.Error(TAG, `found more than one asset with uri: ${assetUri}`);
                return;
            }

            let asset = await assetResult.getFirstObject();
            let photoItem = new PhotoItem(asset);

            Logger.Info(TAG, `prepending new asset: ${photoItem.displayName}, uri: ${photoItem.uri}`);
            this.doAddPhotoItem(photoItem, AddPosition.Prepend);
            assetResult.close();
        } catch (error) {
            Logger.Error(TAG, `failed to add new asset: ${error}`);
        }
    }

    private async getAllCategories(): Promise<number[]> {
        const FETCH_OPTIONS: photoAccessHelper.FetchOptions = {
            fetchColumns: [
                photoAccessHelper.PhotoKeys.URI,
                photoAccessHelper.PhotoKeys.DATE_TAKEN,
                photoAccessHelper.PhotoKeys.DISPLAY_NAME,
                photoAccessHelper.PhotoKeys.OWNER_ALBUM_ID,
            ],
            predicates: new dataSharePredicates.DataSharePredicates()
                .orderByDesc(photoAccessHelper.PhotoKeys.DATE_TAKEN)
        };

        let albums: number[] = [];
        try {
            let result = await NCommon.pHelper.getAssets(FETCH_OPTIONS);
            while (!result.isAfterLast()) {
                const photoItem = await result.getNextObject();
                const albumId = photoItem.get(photoAccessHelper.PhotoKeys.OWNER_ALBUM_ID) as number;
                if (!albums.includes(albumId)) {
                    albums.push(albumId);
                    const displayName = photoItem.get(photoAccessHelper.PhotoKeys.DISPLAY_NAME);
                    Logger.Debug(TAG, `found albumId: ${albumId} via '${displayName}'`);
                }
            }
        } catch (e) {
            Logger.Info(TAG, `failed to get all photos: ${JSON.stringify(e)}`);
        }
        albums.sort((a, b) => a - b);
        return albums;
    }

    private async doAddPhotoItem(photoItem: PhotoItem, addPosition: AddPosition) {
        let ownerAlbumId = photoItem.ownerAlbumId;
        let category = this.categories.get(ownerAlbumId);
        if (category) {
            category.tryAddAsset(photoItem, addPosition);

            let account = Nextcloud.getAllAccounts()[0];
            let remoteFolderId = account.dbAccount.config.instantUploadFolderId;
            let remoteFolder = await Nextcloud.getSyncFolderManager().getRemoteFolderById(remoteFolderId);
            Logger.Info(TAG, `instant upload remote dir: ${remoteFolderId}`);
            photoItem.getUploadJob(category.name, remoteFolder!).start();
        } else {
            Logger.Error(TAG, `add new category for ${ownerAlbumId} failed`);
        }
    }
}

export const PhotoAssetsManager = new PhotoAssetsManagerImpl();
