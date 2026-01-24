import { wantAgent } from '@kit.AbilityKit';
import backgroundTaskManager from '@ohos.resourceschedule.backgroundTaskManager';
import { Logger } from 'nextcloud';
import { BUNDLE_NAME } from 'BuildProfile';
import { BusinessError } from '@ohos.base';
import { notificationManager } from '@kit.NotificationKit';

const TAG = "Util-NotificationManager";

class NotificationImpl {
    private readonly WANT_AGENT_INFO: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: BUNDLE_NAME, abilityName: "EntryAbility" }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
    };

    private notificationId: Optional<number> = undefined;
    private idleTimer: number = 0;

    public async startNotification(context: Context) {
        Logger.Info(TAG, `startNotification`);
        try {
            let wantAgentObj = await wantAgent.getWantAgent(this.WANT_AGENT_INFO);
            let req = new backgroundTaskManager.ContinuousTaskRequest();
            req.backgroundTaskModes = [backgroundTaskManager.BackgroundTaskMode.MODE_TASK_KEEPING];
            req.backgroundTaskSubmodes = [backgroundTaskManager.BackgroundTaskSubmode.SUBMODE_NORMAL_NOTIFICATION];
            req.wantAgent = wantAgentObj;

            let res = await backgroundTaskManager.startBackgroundRunning(context, req);
            Logger.Info(TAG, `${JSON.stringify(res)}`);


            this.notificationId = 111;
            await this.startIdleLoop();
            Logger.Info(TAG, `startNotification: succeeded: ${this.notificationId}`);
        } catch (error) {
            let e = error as BusinessError;
            Logger.Error(TAG, `startNotification: failed. code is ${e.code} message is ${e.message}`);
        }
    }

    public async beginIdle() {
        Logger.Info(TAG, `startIdle: enter`);
        if (this.notificationId === undefined) {
            Logger.Warn(TAG, `startIdle: notificationId is undefined, return directly`);
            return;
        }
        await this.startIdleLoop();
    }

    public async publishNotification(title: string, content: string, percent: number) {
        if (this.notificationId === undefined) {
            Logger.Warn(TAG, "publishUploadProgress: notificationId is undefined, return directly");
            return;
        }

        clearInterval(this.idleTimer);
        await this.doPublishNotification(title, content, percent);
    }

    private async startIdleLoop(): Promise<void> {
        let doPublishIdleNotificaton = async () => {
            await this.doPublishNotification('Nexcloud is Idle', `Since ${new Date().toLocaleTimeString()}`, 1);
        };

        await doPublishIdleNotificaton();
        clearInterval(this.idleTimer);
        this.idleTimer = setInterval(async () => {
            await doPublishIdleNotificaton();
        }, 90 * 1000); ///< 90s
    }

    private async doPublishNotification(title: string, subtitle: string, progress: number) {
        Logger.Info(TAG, `doPublishNotification: '${title}', '${subtitle}', ${progress}% -> ${this.notificationId}`);
        let downloadTemplate: notificationManager.NotificationTemplate = {
            name: 'downloadTemplate',
            data: {
                title: title,
                fileName: subtitle,
                progressValue: progress,
            }
        };

        let notificationRequest: notificationManager.NotificationRequest = {
            id: this.notificationId,
            content: {
                notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
                normal: {
                    title: "<placeholder>",
                    text: "<placeholder>",
                    additionalText: "<placeholder>",
                }
            },
            template: downloadTemplate
        };
        try {
            await notificationManager.publish(notificationRequest);
        } catch (err) {
            Logger.Error(TAG, `doPublishNotification: publish fail: ${JSON.stringify(err)}`);
        }
    }
}

export const NotificationManager = new NotificationImpl();
