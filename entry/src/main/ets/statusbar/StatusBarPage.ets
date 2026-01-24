import {
    TransferTask,
    Logger,
} from 'nextcloud';
import { BusinessError } from '@kit.BasicServicesKit';
import { commonEventManager } from '@kit.BasicServicesKit';
import {
    TRANSFER_MANAGER_COMMON_EVENT_NAME,
    TransferManagerEvent,
    TransferManagerEventCode,
} from 'nextcloud/src/main/ets/SyncEngine/TransferManagerEventIPC';

const TAG = 'StatusBar/Page';

@ComponentV2
struct TransferProgressItem {
    @Require @Param transferTask: TransferTask;

    build() {
        Column({ space: 4 }) {
            Text(this.transferTask.filename)
                .textOverflow({ overflow: TextOverflow.MARQUEE })
                .textAlign(TextAlign.Start)
                .width('100%')

            Progress({
                value: this.transferTask.transferredSize,
                total: this.transferTask.totalSize,
            })
                .flexGrow(1)

            Text(this.transferTask.progressPercentText)
        }
        .backgroundColor($r('sys.color.ohos_id_color_hover'))
        .padding(8)
        .borderRadius(4)
        .width('100%')
    }
}

@Entry
@ComponentV2
struct StatusBarPage {
    @Local tasks: Map<number, TransferTask> = new Map();
    private subscriber: commonEventManager.CommonEventSubscriber | undefined = undefined;
    private readonly subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
        events: [TRANSFER_MANAGER_COMMON_EVENT_NAME]
    };

    private readonly subscribeCB = async (data: commonEventManager.CommonEventData) => {
        console.info(`Succeeded in subscribing, data is ` + JSON.stringify(data));
        let event: TransferManagerEvent = JSON.parse(data.data!);
        switch (event.code) {
            case TransferManagerEventCode.TASK_CREATE: {
                this.tasks.set(event.taskId, new TransferTask(event.task));
                break;
            }
            case TransferManagerEventCode.TASK_PROGRESS: {
                let task = this.tasks.get(event.taskId)!;
                task.transferredSize = event.transferredSize;
                break;
            }
            case TransferManagerEventCode.TASK_COMPLETED: {
                let task = this.tasks.get(event.taskId)!;
                task.transferredSize = task.totalSize;
                break;
            }
            case TransferManagerEventCode.TASK_FAILED: {
                let task = this.tasks.get(event.taskId)!;
                task.transferredSize = 0;
                break;
            }
        }
    }

    async aboutToAppear(): Promise<void> {
        try {
            this.subscriber = await commonEventManager.createSubscriber(this.subscribeInfo);
            Logger.Info(TAG, `succeeded in creating subscriber.`);
            await commonEventManager.subscribeToEvent(this.subscriber, this.subscribeCB);
            Logger.Info(TAG, `succeeded in subscribing`);
        } catch (error) {
            let err: BusinessError = error as BusinessError;
            Logger.Error(TAG, `Failed to create subscriber. Code is ${err.code}, message is ${err.message}`);
        }
    }

    build() {
        Scroll() {
            Column({ space: 16 }) {
                ForEach(Array.from(this.tasks).reverse(), (item: [number, TransferTask]) => {
                    TransferProgressItem({
                        transferTask: item[1]
                    })
                }, (item: [number, TransferTask], index: number) => {
                    return `${item[0]}`
                })
            }
        }
        .padding(16)
        .width('100%')
        .height('100%')
    }
}
