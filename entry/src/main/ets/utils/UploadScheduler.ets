import { Logger, NCommon } from 'nextcloud';
import { AddAssetResult, AddPosition, Category } from '../models/Category';
import { PhotoItem } from '../models/PhotoItem';
import { GlobalStorage } from './GlobalStorage';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { dataSharePredicates } from '@kit.ArkData';
import { Notification } from './NotificationManager';

const TAG = 'Utils-UploadScheduler';

export namespace UploadScheduler {
    export let categories: Category[] = [];

    const FETCH_COLUMNS = [
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
    ];


    function doAddPhotoItem(photoItem: PhotoItem, addPosition: AddPosition) {
        for (let category of categories) {
            if (category.tryAddAsset(photoItem, addPosition) != AddAssetResult.Unmatched) {
                break;
            }
        }
    }


    export async function initialize() {
        while (categories.length > 0) {
            categories.pop();
        }

        for (let c of NCommon.Preference.categories) {
            categories.push(new Category(c));
        }

        const FETCH_OPTIONS: photoAccessHelper.FetchOptions = {
            fetchColumns: FETCH_COLUMNS,
            predicates: new dataSharePredicates.DataSharePredicates().orderByDesc(photoAccessHelper.PhotoKeys.DATE_TAKEN),
        };

        try {
            let result = await GlobalStorage.pHelper.getAssets(FETCH_OPTIONS);
            for (let asset of await result.getAllObjects()) {
                doAddPhotoItem(new PhotoItem(asset), AddPosition.Append);
            }
            result.close();
        } catch (error) {
            Logger.Error(TAG, `failed to get photo assets: ${error}`);
        }
    }


    export async function prependNewAsset(assetUri: string) {
        Logger.Info(TAG, `addNewAsset enter, uri: ${assetUri}`);
        const FETCH_OPTIONS: photoAccessHelper.FetchOptions = {
            fetchColumns: FETCH_COLUMNS,
            predicates: new dataSharePredicates.DataSharePredicates().equalTo(photoAccessHelper.PhotoKeys.URI, assetUri),
        };

        try {
            let assetResult = await GlobalStorage.pHelper.getAssets(FETCH_OPTIONS);
            if (assetResult.getCount() !== 1) {
                Logger.Error(TAG, `found more than one asset with uri: ${assetUri}`);
                return;
            }
            let photoItem = new PhotoItem(await assetResult.getFirstObject());
            Logger.Info(TAG, `prepending new asset: ${photoItem.displayName}, uri: ${photoItem.uri}`);
            doAddPhotoItem(photoItem, AddPosition.Prepend);
            assetResult.close();
        } catch (error) {
            Logger.Error(TAG, `failed to add new asset: ${error}`);
        }
    }

    export async function doFullUpload(notify: boolean = true) {
        for (let category of UploadScheduler.categories) {
            await category.uploadAllAssets(notify);
        }

        await new Promise<void>((resolve) => setTimeout(resolve, 5000)); // wait for 1 second to ensure all uploads are started
        if (notify) {
            await Notification.publishIdleNotification();
        }
    }
}
