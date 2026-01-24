import { BasicDataSource } from '../Utils/BasicDatasource';
import { Logger } from '../Utils/Logger';
import {
    ITransferTask,
    publishTransferEvent,
    TransferManagerEventCode,
    TransferType,
} from './TransferManagerEventIPC';

const TAG = 'SyncEngine/TransferManager';

@ObservedV2
export class TransferTask {
    readonly id: number;
    @Trace public readonly type: TransferType;
    @Trace public readonly filename: string;
    @Trace public totalSize: number = 1;
    @Trace public transferredSize: number = 0;

    constructor(task: ITransferTask) {
        this.id = task.id;
        this.type = task.type;
        this.filename = task.filename;
        this.totalSize = task.totalSize;
        this.transferredSize = task.transferredSize;
    }

    public get progressPercentText() {
        let progress = this.transferredSize / this.totalSize;
        return `${(progress * 100).toFixed(1)}%`;
    }

    public updateProgress(transferredSize: number, totalSize: number): number {
        if (this.totalSize != totalSize) {
            this.totalSize = totalSize;
            publishTransferEvent({
                code: TransferManagerEventCode.TASK_CREATE,
                taskId: this.id,
                task: {
                    id: this.id,
                    type: this.type,
                    filename: this.filename,
                    totalSize: this.totalSize,
                    transferredSize: this.transferredSize
                },
            })
        }

        if (transferredSize !== transferredSize) {
            Logger.Warn(TAG, `transferred size not changed`);
        } else {
            this.transferredSize = transferredSize;

            if (this.transferredSize !== this.totalSize) {
                publishTransferEvent({
                    code: TransferManagerEventCode.TASK_PROGRESS,
                    taskId: this.id,
                    transferredSize: this.transferredSize
                })
            } else {
                publishTransferEvent({
                    code: TransferManagerEventCode.TASK_COMPLETED,
                    taskId: this.id,
                })
            }
        }
        return this.transferredSize / this.totalSize;
    }
}

export class TransferManagerImpl {
    private tasks_: BasicDataSource<TransferTask>;
    private idSeq_ = 0;

    constructor() {
        Logger.Info(TAG, `created TransferManager`);
        this.tasks_ = new BasicDataSource<TransferTask>();
    }

    public get tasks() {
        return this.tasks_;
    }

    public addTransferTask(type: TransferType, fileName: string): TransferTask {
        let id = this.idSeq_++;
        let task = new TransferTask({ id, type, filename: fileName, transferredSize: 0, totalSize: 0 });
        return this.tasks_.prependItem(task);
    }
}

export let TransferManager = new TransferManagerImpl();
