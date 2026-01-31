import { Logger } from 'nextcloud';
import { notificationManager } from '@kit.NotificationKit';

const TAG = "Util-NotificationManager";

export class Notification {
    private static nextId = 1;
    private readonly nId: number;

    private constructor(nId: number) {
        this.nId = nId;
    }

    public static async publishNotification(title: string, content: string, percent: number): Promise<Notification> {
        let n = new Notification(Notification.nextId++);
        await n.publishNotification(title, content, percent);
        return n;
    }

    public async cancel(timeout: number = 0) {
        if (this.nId === undefined) {
            Logger.Warn(TAG, "cancelNotification: notificationId is undefined, return directly");
            return;
        }

        if (timeout) {
            setTimeout(async () => {
                await this.doCancel();
            }, timeout);
        } else {
            await this.doCancel();
        }
    }

    public async publishNotification(title: string, content: string, percent: number) {
        if (this.nId === undefined) {
            Logger.Warn(TAG, "publishUploadProgress: notificationId is undefined, return directly");
            return;
        }

        await this.doPublish(title, content, percent);
    }

    private async doCancel() {
        try {
            await notificationManager.cancel(this.nId);
            Logger.Info(TAG, `doCancelNotification: cancelled notification id ${this.nId}`);
        } catch (err) {
            Logger.Error(TAG, `doCancelNotification: cancel fail: ${JSON.stringify(err)}`);
        }
    }

    private async doPublish(title: string, subtitle: string, progress: number) {
        Logger.Info(TAG, `doPublishNotification: '${title}', '${subtitle}', ${progress}% -> ${this.nId}`);
        let downloadTemplate: notificationManager.NotificationTemplate = {
            name: 'downloadTemplate',
            data: {
                title: title,
                fileName: subtitle,
                progressValue: progress,
            }
        };

        let notificationRequest: notificationManager.NotificationRequest = {
            id: this.nId,
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
