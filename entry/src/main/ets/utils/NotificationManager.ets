import { wantAgent } from '@kit.AbilityKit';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import { Logger } from 'nextcloud';
import { BUNDLE_NAME } from 'BuildProfile';
import { BusinessError } from '@ohos.base';
import { notificationManager } from '@kit.NotificationKit';
import { PhotoAssetsManager } from './PhotoAssetsManager';

const TAG = "Util-NotificationManager";

class NotificationImpl {
    private readonly WANT_AGENT_INFO: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: BUNDLE_NAME, abilityName: "EntryAbility" }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };
    private readonly BACKGROUND_JOB_TYPE: Array<string> = ["dataTransfer"];
    private notificationId: Optional<number> = undefined;
    private refreshNotificationTimer: number = 0;

    public async startNotification(context: Context) {
        try {
            let wantAgentObj = await wantAgent.getWantAgent(this.WANT_AGENT_INFO);
            let res = await backgroundTaskManager.startBackgroundRunning(context, this.BACKGROUND_JOB_TYPE, wantAgentObj);
            this.notificationId = res.notificationId;
            await this.publishIdleNotification();
            Logger.Info(TAG, `Operation startBackgroundRunning succeeded: ${this.notificationId}`);
        } catch (error) {
            let e = error as BusinessError;
            Logger.Error(TAG, `Operation startBackgroundRunning failed. code is ${e.code} message is ${e.message}`);
        }
    }

    public async publishUploadProgress(currentNumber: number, totalNumber: number) {
        if (this.notificationId === undefined) {
            Logger.Warn(TAG, "publishUploadProgress: notificationId is undefined, return directly");
            return;
        }
        let process = Math.floor((currentNumber / totalNumber) * 100);
        await this.publishUploadProgressInner('Nextcloud Upload', `Uploading ${currentNumber} of ${totalNumber}`, process);
    }

    public async publishIdleNotification() {
        if (this.notificationId === undefined) {
            Logger.Warn(TAG, "publishIdleUploadNotification: notificationId is undefined, return directly");
            return;
        }

        let randomProgress = Math.floor(Math.random() * 100);
        await this.publishUploadProgressInner('Nextcloud is Idle', `Since ${new Date().toLocaleTimeString()}`, randomProgress);

        clearInterval(this.refreshNotificationTimer);
        this.refreshNotificationTimer = setInterval(async () => {
            await this.publishIdleNotification();
            await PhotoAssetsManager.doFullUpload(false); // false = do not notify again
        }, 3 * 30 * 1000);
    }

    public async publishPendingNotification(due: Date, percent: number) {
        if (this.notificationId === undefined) {
            Logger.Warn(TAG, "publishIdleUploadNotification: notificationId is undefined, return directly");
            return;
        }
        await this.publishUploadProgressInner('Nextcloud Pending Upload', `Scheduled at ${due.toLocaleTimeString()}`, percent);
    }

    private async publishUploadProgressInner(title: string, subtitle: string, progress: number) {
        clearInterval(this.refreshNotificationTimer);
        await this.doPublishUploadProgress(title, subtitle, progress);
    }

    private async doPublishUploadProgress(title: string, subtitle: string, progress: number) {
        Logger.Info(TAG, `publishUploadProgress: title='${title}', subtitle='${subtitle}', progress=${progress} to ${this.notificationId}`);
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
            id: this.notificationId,
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

export const Notification = new NotificationImpl();
