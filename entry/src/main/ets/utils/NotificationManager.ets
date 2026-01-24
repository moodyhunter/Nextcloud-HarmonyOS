import { Logger } from 'nextcloud';
import { notificationManager } from '@kit.NotificationKit';

const TAG = "Util-NotificationManager";

class Notification {
    private notificationId: Optional<number> = undefined;

    public async cancelNotification(timeout: number = 0) {
        if (this.notificationId === undefined) {
            Logger.Warn(TAG, "cancelNotification: notificationId is undefined, return directly");
            return;
        }

        if (timeout) {
            setTimeout(async () => {
                await this.doCancelNotification();
            }, timeout);
        } else {
            await this.doCancelNotification();
        }
    }

    public async publishNotification(title: string, content: string, percent: number) {
        if (this.notificationId === undefined) {
            Logger.Warn(TAG, "publishUploadProgress: notificationId is undefined, return directly");
            return;
        }

        await this.doPublishNotification(title, content, percent);
    }

    private async doCancelNotification() {
        try {
            await notificationManager.cancel(this.notificationId);
            Logger.Info(TAG, `doCancelNotification: cancelled notification id ${this.notificationId}`);
        } catch (err) {
            Logger.Error(TAG, `doCancelNotification: cancel fail: ${JSON.stringify(err)}`);
        }
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

export namespace NotificationManager {
    export async function publishNotification(title: string, content: string, percent: number): Promise<Notification> {
        let notification = new Notification();
        notification.publishNotification(title, content, percent);
        return notification;
    }
}
