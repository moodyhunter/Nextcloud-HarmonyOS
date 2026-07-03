import { commonEventManager } from '@kit.BasicServicesKit';
import { Logger } from 'nextcloud';
import {
    TransferJobBasicInfo,
    TRANSFER_MANAGER_COMMON_EVENT_NAME,
    TransferManagerEvent,
    TransferManagerEventCode,
    TransferType
} from 'nextcloud/src/main/ets/SyncEngine/TransferManagerEventIPC';

const TAG = 'StatusBar/TransferStatusReceiver';

@ObservedV2
export class TransferJobStatus {
    @Trace id: number;
    @Trace type: TransferType;
    @Trace fileName: string;
    @Trace totalSize: number;
    @Trace transferredSize: number;

    constructor(task: TransferJobBasicInfo) {
        this.id = task.id;
        this.type = task.type;
        this.fileName = task.fileName;
        this.totalSize = task.totalSize;
        this.transferredSize = task.transferredSize;
    }

    public get progressPercentText() {
        let progress = this.transferredSize / this.totalSize;
        return `${(progress * 100).toFixed(1)}%`;
    }
}

@ObservedV2
export class TransferStatusReceiver {
    @Trace tasks: Map<number, TransferJobStatus> = new Map();
    private subscriber: commonEventManager.CommonEventSubscriber | undefined = undefined;
    private readonly subscribeInfo: commonEventManager.CommonEventSubscribeInfo = {
        events: [TRANSFER_MANAGER_COMMON_EVENT_NAME]
    };
    private readonly subscribeCB = async (data: commonEventManager.CommonEventData) => {
        console.info(`Succeeded in subscribing, data is ` + JSON.stringify(data));
        let event: TransferManagerEvent = JSON.parse(data.data!);
        switch (event.code) {
            case TransferManagerEventCode.TASK_CREATED: {
                this.tasks.set(event.taskId, new TransferJobStatus(event.task));
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

    constructor() {
        this.doSubscribe();
    }

    private async doSubscribe() {
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
}
