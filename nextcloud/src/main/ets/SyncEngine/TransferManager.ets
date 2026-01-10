import { BasicDataSource } from '../Utils/BasicDatasource';

export enum TransferType {
    DOWNLOAD,
    UPLOAD,
}

@Observed
export class TransferTask {
    public readonly type: TransferType;
    public readonly filename: string;
    public totalSize: number = 1;
    public transferredSize: number = 0;

    constructor(type: TransferType, filename: string) {
        this.type = type;
        this.filename = filename;
    }

    public get progressPercentText() {
        let progress = this.transferredSize / this.totalSize;
        return `${(progress * 100).toFixed(1)}%`;
    }

    public updateProgress(transferredSize: number, totalSize: number): number {
        if (this.totalSize != totalSize) {
            this.totalSize = totalSize;
        }
        this.transferredSize = transferredSize;
        return this.transferredSize / this.totalSize;
    }
}

@Observed
export class TransferManagerImpl {
    private tasks_: BasicDataSource<TransferTask>;

    constructor() {
        this.tasks_ = new BasicDataSource<TransferTask>();
    }

    public get tasks() {
        return this.tasks_;
    }

    public addTransferTask(type: TransferType, fileName: string): TransferTask {
        let task = new TransferTask(type, fileName);
        return this.tasks_.prependItem(task);
    }
}


export let TransferManager = new TransferManagerImpl();
