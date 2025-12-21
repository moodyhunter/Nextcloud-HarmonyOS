import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { Logger } from 'nextcloud';
import { GlobalStorage } from './GlobalStorage';
import { Notification } from './NotificationManager';
import { UploadScheduler } from './UploadScheduler';

const TAG = 'Utils-PhotoMonitor';

export namespace PhotoMonitor {
    let doUploadTimer: number | undefined = undefined;
    const UPLOAD_DELAY_MS = 30 * 1000; // wait for this time before triggering full upload

    let fullUploadTimer: number | undefined = undefined;
    const FULL_UPLOAD_INTERVAL_MS = 60 * 60 * 1000; // perform full upload at least every hour

    function scheduleFullUpload() {
        clearInterval(fullUploadTimer);

        fullUploadTimer = setInterval(async () => {
            Logger.Info(TAG, `>>> Scheduled full upload beginning`);
            await UploadScheduler.doFullUpload();
            let nextTime = new Date(Date.now() + FULL_UPLOAD_INTERVAL_MS);
            Logger.Info(TAG, `<<< Scheduled full upload completed, next time: ${nextTime}`);
        }, FULL_UPLOAD_INTERVAL_MS);

        let nextUploadTime = new Date(Date.now() + FULL_UPLOAD_INTERVAL_MS);
        Logger.Info(TAG, `+++ Scheduled full upload at ${nextUploadTime}`);
    }

    async function doOnPhotoChanged(changeData: photoAccessHelper.ChangeData) {
        if (changeData.type !== photoAccessHelper.NotifyType.NOTIFY_ADD) {
            Logger.Debug(TAG, `change type isn't ADD, return directly`);
            return;
        }

        for (let uri of changeData.uris) {
            await UploadScheduler.prependNewAsset(uri);
        }

        clearTimeout(doUploadTimer); // cancel repeating upload timer
        clearInterval(fullUploadTimer); // postpone full upload timer after photo change

        doUploadTimer = setTimeout(async () => {
            Logger.Info(TAG, `>>> Scheduled photo upload beginning`);
            await UploadScheduler.doFullUpload();
            Logger.Info(TAG, `<<< Scheduled photo upload completed`);
            scheduleFullUpload();
        }, UPLOAD_DELAY_MS);

        let nextUploadTime = new Date(Date.now() + UPLOAD_DELAY_MS);
        Notification.publishPendingNotification(nextUploadTime, 66);
        Logger.Info(TAG, `+++ Scheduled upload at ${nextUploadTime}`);
    }

    export function beginMonitorPhotoChange() {
        try {
            GlobalStorage.pHelper.registerChange(photoAccessHelper.DefaultChangeUri.DEFAULT_PHOTO_URI, true, doOnPhotoChanged);
            scheduleFullUpload();
        } catch (error) {
            Logger.Error(TAG, `Failed to register photo change monitor: ${error}`);
        }
    }

    export function stopMonitorPhotoChange() {
        try {
            GlobalStorage.pHelper.unRegisterChange(photoAccessHelper.DefaultChangeUri.DEFAULT_PHOTO_URI, doOnPhotoChanged);
        } catch (error) {
            Logger.Error(TAG, `Failed to unregister photo change monitor: ${error}`);
        }

    }
}
