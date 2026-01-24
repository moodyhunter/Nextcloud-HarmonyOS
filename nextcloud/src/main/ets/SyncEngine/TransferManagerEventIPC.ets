import { commonEventManager } from '@kit.BasicServicesKit';
import { Logger } from '../Index';

const TAG = 'SyncEngine/TransferManager/IPC';

export enum TransferType {
    Download,
    Upload,
}

export interface TransferJobBasicInfo {
    id: number;
    type: TransferType;
    fileName: string;
    totalSize: number;
    transferredSize: number;
}

export enum TransferManagerEventCode {
    TASK_CREATED = 1,
    TASK_PROGRESS = 2,
    TASK_COMPLETED = 3,
    TASK_FAILED = 4,
}

interface TransferManagerEvent_TaskCreate {
    code: TransferManagerEventCode.TASK_CREATED;
    taskId: number;
    task: TransferJobBasicInfo;
};

interface TransferManagerEvent_TaskProgress {
    code: TransferManagerEventCode.TASK_PROGRESS;
    taskId: number;
    transferredSize: number;
};

interface TransferManagerEvent_TaskCompleted {
    code: TransferManagerEventCode.TASK_COMPLETED;
    taskId: number;
};

interface TransferManagerEvent_TaskFailed {
    code: TransferManagerEventCode.TASK_FAILED;
    taskId: number;
};

export type TransferManagerEvent =
    TransferManagerEvent_TaskCreate
        | TransferManagerEvent_TaskProgress
        | TransferManagerEvent_TaskCompleted
        | TransferManagerEvent_TaskFailed;

export const TRANSFER_MANAGER_COMMON_EVENT_NAME: string = 'Nextcloud.TransferManager.Events';

function noop() {
}

export function publishTransferEvent(event: TransferManagerEvent) {
    let options: commonEventManager.CommonEventPublishData = {
        data: JSON.stringify(event),
    };
    Logger.Debug(TAG, `published transfer event: ${options.data}`);
    commonEventManager.publish(TRANSFER_MANAGER_COMMON_EVENT_NAME, options, noop);
}
