import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { Logger, NCommon } from 'nextcloud';
import { GlobalStorage } from './GlobalStorage';
import { NotificationManager } from './NotificationManager';
import { PhotoAssetsManager } from 'nextcloud';

const TAG = 'Utils-PhotoMonitor';

class PhotoMonitorImpl {
    private static readonly FULL_UPLOAD_INTERVAL_MS = 60 * 60 * 1000; // perform full upload at least every hour
    private static readonly UPLOAD_DELAY_MS = 30 * 1000; // wait for this time before triggering full upload
    private doUploadTimer: number | undefined = undefined;
    private fullUploadTimer: number | undefined = undefined;
    private readonly onPhotoChangedCallback = async (changeData: photoAccessHelper.ChangeData): Promise<void> => {
        await this.doOnPhotoChanged(changeData);
    };

    public beginMonitorPhotoChange() {
        try {
            NCommon.pHelper.registerChange(
                photoAccessHelper.DefaultChangeUri.DEFAULT_PHOTO_URI,
                true,
                this.onPhotoChangedCallback
            );
        } catch (error) {
            Logger.Error(TAG, `Failed to register photo change monitor: ${error}`);
        }

        this.scheduleFullUpload();
    }

    public stopMonitorPhotoChange() {
        try {
            NCommon.pHelper.unRegisterChange(
                photoAccessHelper.DefaultChangeUri.DEFAULT_PHOTO_URI,
                this.onPhotoChangedCallback
            );
        } catch (error) {
            Logger.Error(TAG, `Failed to unregister photo change monitor: ${error}`);
        }

    }

    private async scheduleFullUpload() {
        clearInterval(this.fullUploadTimer);

        this.fullUploadTimer = setInterval(async () => {
            Logger.Info(TAG, `>>> Scheduled full upload beginning`);
            // await PhotoAssetsManager.doFullUpload();
            let nextTime = new Date(Date.now() + PhotoMonitorImpl.FULL_UPLOAD_INTERVAL_MS);
            Logger.Info(TAG, `<<< Scheduled full upload completed, next time: ${nextTime}`);
        }, PhotoMonitorImpl.FULL_UPLOAD_INTERVAL_MS);

        let nextUploadTime = new Date(Date.now() + PhotoMonitorImpl.FULL_UPLOAD_INTERVAL_MS);
        Logger.Info(TAG, `+++ Scheduled full upload at ${nextUploadTime}`);
    }

    private async doOnPhotoChanged(changeData: photoAccessHelper.ChangeData) {
        if (changeData.type !== photoAccessHelper.NotifyType.NOTIFY_ADD) {
            Logger.Debug(TAG, `change type isn't ADD, return directly`);
            return;
        }

        for (let uri of changeData.uris) {
            await PhotoAssetsManager.prependNewAsset(uri);
        }

        clearTimeout(this.doUploadTimer); // cancel repeating upload timer
        clearInterval(this.fullUploadTimer); // postpone full upload timer after photo change

        this.doUploadTimer = setTimeout(async () => {
            Logger.Info(TAG, `>>> Scheduled photo upload beginning`);
            // await PhotoAssetsManager.doFullUpload();
            Logger.Info(TAG, `<<< Scheduled photo upload completed`);
            this.scheduleFullUpload();
        }, PhotoMonitorImpl.UPLOAD_DELAY_MS);

        let nextUploadTime = new Date(Date.now() + PhotoMonitorImpl.UPLOAD_DELAY_MS);
        NotificationManager.publishNotification('nextUploadTime', '', 1);
        Logger.Info(TAG, `+++ Scheduled upload at ${nextUploadTime}`);
    }
}

export const PhotoMonitor = new PhotoMonitorImpl();
