import { wantAgent } from '@kit.AbilityKit';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import { Logger } from 'nextcloud';
import { BUNDLE_NAME } from 'BuildProfile';
import { BusinessError } from '@ohos.base';
import { notificationManager } from '@kit.NotificationKit';
import { UploadScheduler } from './UploadScheduler';

const TAG = "Util-NotificationManager";

export namespace Notification {
    const WANT_AGENT_INFO: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: BUNDLE_NAME, abilityName: "EntryAbility" }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    const BACKGROUND_JOB_TYPE: Array<string> = ["dataTransfer"];
    let notificationId: Optional<number> = undefined;
    let refreshNotificationTimer: number = 0;


    export async function startNotification(context: Context) {
        try {
            let wantAgentObj = await wantAgent.getWantAgent(WANT_AGENT_INFO);
            let res = await backgroundTaskManager.startBackgroundRunning(context, BACKGROUND_JOB_TYPE, wantAgentObj);
            notificationId = res.notificationId;
            await publishIdleNotification();
            Logger.Info(TAG, `Operation startBackgroundRunning succeeded: ${notificationId}`);
        } catch (error) {
            let e = error as BusinessError;
            Logger.Error(TAG, `Operation startBackgroundRunning failed. code is ${e.code} message is ${e.message}`);
        }
    }

    export async function publishUploadProgress(currentNumber: number, totalNumber: number) {
        if (notificationId === undefined) {
            Logger.Warn(TAG, "publishUploadProgress: notificationId is undefined, return directly");
            return;
        }
        let process = Math.floor((currentNumber / totalNumber) * 100);
        await publishUploadProgressInner('Nextcloud Upload', `Uploading ${currentNumber} of ${totalNumber}`, process);
    }

    export async function publishIdleNotification() {
        if (notificationId === undefined) {
            Logger.Warn(TAG, "publishIdleUploadNotification: notificationId is undefined, return directly");
            return;
        }

        let randomProgress = Math.floor(Math.random() * 100);
        await UploadScheduler.doFullUpload(false);
        await publishUploadProgressInner('Nextcloud is Idle', `Since ${new Date().toLocaleTimeString()}`, randomProgress);

        clearInterval(refreshNotificationTimer);
        refreshNotificationTimer = setInterval(async () => {
            await publishIdleNotification();
        }, 3 * 30 * 1000);
    }

    export async function publishPendingNotification(due: Date, percent: number) {
        if (notificationId === undefined) {
            Logger.Warn(TAG, "publishIdleUploadNotification: notificationId is undefined, return directly");
            return;
        }
        await publishUploadProgressInner('Nextcloud Pending Upload', `Scheduled at ${due.toLocaleTimeString()}`, percent);
    }

    async function publishUploadProgressInner(title: string, subtitle: string, progress: number) {
        clearInterval(refreshNotificationTimer);
        await doPublishUploadProgress(title, subtitle, progress);
    }

    async function doPublishUploadProgress(title: string, subtitle: string, progress: number) {
        Logger.Info(TAG, `publishUploadProgress: title='${title}', subtitle='${subtitle}', progress=${progress} to ${notificationId}`);
        let downloadTemplate: notificationManager.NotificationTemplate = {
            name: 'downloadTemplate',
            data: {
                title: title,
                fileName: subtitle,
                progressValue: progress,
            }
        };

        let request: notificationManager.NotificationRequest = {
            content: {
                notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_SYSTEM_LIVE_VIEW,
                systemLiveView: { typeCode: 8, title: '<placeholder>', text: '<placeholder>', }
            },
            id: notificationId,
            notificationSlotType: notificationManager.SlotType.LIVE_VIEW,
            template: downloadTemplate,
        };

        try {
            await notificationManager.publish(request);
        } catch (err) {
            Logger.Error(TAG, `publish fail: ${JSON.stringify(err)}`);
        }
    }
}
